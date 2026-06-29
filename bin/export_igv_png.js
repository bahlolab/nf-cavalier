#!/usr/bin/env node

const fs = require("fs");
const path = require("path");
const puppeteer = require("puppeteer");

async function sleep(ms) {
    return new Promise(r => setTimeout(r, ms));
}

// ---------------------------------------------------------------------------
// robust wait-for-PNG helper
// ---------------------------------------------------------------------------
async function waitForPNG(dir, timeout = 30000) {
    const targetFile = 'igvjs.png';
    const filePath = path.join(dir, targetFile);
    const start = Date.now();
    const minSize = 1000; // Minimum 1KB to be considered valid

    while (Date.now() - start < timeout) {
        if (fs.existsSync(filePath)) {
            // Wait a bit more to ensure write is complete
            await sleep(500);
            const stats = fs.statSync(filePath);
            if (stats.size > minSize) {
                return targetFile;
            }
            console.log(`   ⚠ PNG exists but too small (${stats.size} bytes), waiting...`);
        }
        await sleep(100);
    }

    return null;
}

// ---------------------------------------------------------------------------

(async () => {

    const outDir = ".";
    const input = process.argv[2];
    const prefix = process.argv[3] || "";

    const viewportWidth  = process.argv[4] ? parseInt(process.argv[4], 10) : 800;
    const viewportHeight = process.argv[5] ? parseInt(process.argv[5], 10) : 800;
    const scaleFactor    = process.argv[6] ? parseFloat(process.argv[6]) : 2;

    if (!input) {
        console.error("Usage: export_igv_png.js <report.html> [prefix] [width] [height] [scale]");
        process.exit(1);
    }

    fs.mkdirSync(outDir, { recursive: true });

    const browser = await puppeteer.launch({
        headless: "new",
        executablePath: process.env.CHROMIUM_PATH || undefined,
        defaultViewport: {
            width: viewportWidth,
            height: viewportHeight,
            deviceScaleFactor: scaleFactor
        },
        args: [
            "--no-sandbox",
            "--disable-setuid-sandbox",
            "--allow-file-access-from-files",
            "--disable-dev-shm-usage"  // Helps with shared memory issues
        ]
    });

    const page = await browser.newPage();
    page.on('console', msg => console.log('BROWSER LOG:', msg.text()));

    // Enable downloads
    const client = await page.target().createCDPSession();
    await client.send("Page.setDownloadBehavior", {
        behavior: "allow",
        downloadPath: path.resolve(outDir)
    });

    console.log("Loading page:", input);
    await page.goto(`file:${path.resolve(input)}`, {
        waitUntil: "networkidle0"
    });

    // ---- WAIT FOR VARIANT TABLE ----
    console.log("Waiting for variant table…");
    await page.waitForFunction(() => {
        const table = document.querySelector("#variant_table");
        return table && table.querySelectorAll("tr").length > 1;
    }, { timeout: 60000 });

    console.log("Variant table detected.");

    // Extract variants list inside page
    const variants = await page.evaluate(() => {
        const rows = [...document.querySelectorAll("#variant_table tr")];
        return rows
            .map((row, idx) => {
                const tds = row.querySelectorAll("td");
                if (tds.length < 4) return null;
                return {
                    rowIndex: idx,
                    id: tds[3].innerText.trim()
                };
            })
            .filter(v => v && v.id !== "");
    });

    console.log(`Found ${variants.length} variants.`);

    // -----------------------------------------------------------------------
    //   FUNCTION: Trigger Save → Save as PNG with RETRY
    // -----------------------------------------------------------------------
    async function savePNG(variantID, retries = 2) {
        for (let attempt = 0; attempt <= retries; attempt++) {
            try {
                if (attempt > 0) {
                    console.log(`   Retry attempt ${attempt} for ${variantID}`);
                    await sleep(1000); // Wait before retry
                }

                await page.evaluate(() => {
                    const root = document.querySelector("#igvDiv").shadowRoot;
                    const btn = root.querySelector('div[title="Save Image"]');
                    ["pointerdown", "mousedown", "pointerup", "mouseup", "click"].forEach(ev =>
                        btn.dispatchEvent(new Event(ev, { bubbles: true, composed: true }))
                    );
                });

                await page.waitForFunction(() => {
                    const root = document.querySelector("#igvDiv").shadowRoot;
                    return !!root.querySelector(".igv-ui-dropdown");
                }, { timeout: 5000 });

                await page.evaluate(() => {
                    const root = document.querySelector("#igvDiv").shadowRoot;
                    const pngItem = [...root.querySelectorAll(".igv-ui-dropdown div div")]
                        .find(el => el.textContent.trim() === "Save as PNG");

                    ["pointerdown", "mousedown", "pointerup", "mouseup", "click"].forEach(ev =>
                        pngItem.dispatchEvent(new Event(ev, { bubbles: true, composed: true }))
                    );
                });

                const downloaded = await waitForPNG(outDir, 30000);
                if (!downloaded) {
                    throw new Error(`PNG did not appear or was too small`);
                }

                const finalName = path.join(outDir, `${prefix}${variantID}.png`);
                
                // Verify file before rename
                const stats = fs.statSync(downloaded);
                if (stats.size < 1000) {
                    fs.unlinkSync(downloaded); // Clean up bad file
                    throw new Error(`PNG file too small (${stats.size} bytes)`);
                }
                
                fs.renameSync(downloaded, finalName);
                return; // Success!

            } catch (err) {
                if (attempt === retries) {
                    console.error(`   ✖ Failed to save ${variantID} after ${retries + 1} attempts: ${err.message}`);
                    throw err;
                }
            }
        }
    }

    // -----------------------------------------------------------------------
    //   FUNCTION: click cell to update IGV locus
    // -----------------------------------------------------------------------
    async function clickVariantRow(idx) {
        await page.evaluate((rowIndex) => {
            const row = document.querySelectorAll("#variant_table tr")[rowIndex];
            if (!row) return;
            const cell = row.querySelectorAll("td")[3];
            if (!cell) return;

            ["pointerdown", "mousedown", "mouseup", "pointerup", "click"].forEach(ev =>
                cell.dispatchEvent(new Event(ev, { bubbles: true, composed: true }))
            );
        }, idx);
    }

    // -----------------------------------------------------------------------
    //   MAIN LOOP
    // -----------------------------------------------------------------------
    for (const v of variants) {
        console.log(`→ Selecting variant: ${v.id}`);

        await clickVariantRow(v.rowIndex);
        await sleep(500);   // Increased wait time for IGV rendering
        
        console.log("   Saving PNG…");
        await savePNG(v.id);

        console.log(`   ✔ Saved ${prefix}${v.id}.png`);
    }

    console.log("All variants processed.");

    await browser.close();
})();
