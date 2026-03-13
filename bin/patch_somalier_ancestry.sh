#!/usr/bin/env bash
# Patch somalier-ancestry.html to enable the sample search box.
#
# Usage:
#   bash patch_somalier_ancestry.sh somalier-ancestry.html
#   bash patch_somalier_ancestry.sh somalier-ancestry.html -o patched.html

set -euo pipefail

usage() { echo "Usage: $0 <somalier-ancestry.html> [-o output.html]" >&2; exit 1; }

INPUT=""
OUTPUT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--output) OUTPUT="$2"; shift 2 ;;
        -h|--help) usage ;;
        *) INPUT="$1"; shift ;;
    esac
done
[[ -z "$INPUT" ]] && usage
[[ -z "$OUTPUT" ]] && OUTPUT="$INPUT"

# Find anchor line numbers in the original file
line_pa=$(awk '/^var pa = document\.getElementById\("plota"\)$/{print NR; exit}' "$INPUT")
line_react=$(awk '/Plotly\.react\(pa, traces, layout_a\)/{print NR; exit}' "$INPUT")
line_select=$(awk '/^\/\/ select listeners for plot A$/{print NR; exit}' "$INPUT")
line_react_close=$(awk -v start="$line_react" 'NR > start && NF > 0 {print NR; exit}' "$INPUT")
line_script=$(awk '/^<\/script>$/{n=NR} END{print n}' "$INPUT")
line_script_content=$(awk -v end="$line_script" 'NR < end && NF > 0 {n=NR} END{print n}' "$INPUT")

if [[ -z "$line_pa" || -z "$line_select" || -z "$line_react" || -z "$line_react_close" || -z "$line_script" || -z "$line_script_content" ]]; then
    echo "Error: could not find anchor lines — already patched or unexpected somalier version?" >&2
    exit 1
fi

{
    # Lines before "var pa = ..."
    head -n $((line_pa - 1)) "$INPUT"

    # Inserted: highlight trace block
    cat <<'HIGHLIGHT'
// highlight trace for searched sample (appended last so it renders on top)
var highlight_trace = {
    x: [], y: [], text: [], mode: 'markers', type: 'scattergl',
    showlegend: false, hoverinfo: 'text', name: 'selected',
    marker: { size: 16, color: 'rgba(0,0,0,0)', symbol: 'square',
              line: { color: 'black', width: 3 } }
}
traces.push(highlight_trace)

HIGHLIGHT

    # Lines from "var pa = ..." up to (not including) "// select listeners"
    sed -n "${line_pa},$((line_select - 1))p" "$INPUT"

    # Inserted: update_highlight function
    cat <<'UPDATE_HIGHLIGHT'
function update_highlight() {
    var sample = (typeof sample_search_obj !== 'undefined') ? sample_search_obj.items[0] : null
    var xi = parseInt(jQuery('#plotax_select').val())
    var yi = parseInt(jQuery('#plotay_select').val())
    var hx = [], hy = [], ht = []
    if (sample) {
        var search_prefix = 'sample:' + sample + ' ancestry-probability:'
        for (var _l in query_data) {
            var texts = query_data[_l].text
            for (var _i = 0; _i < texts.length; _i++) {
                if (texts[_i].startsWith(search_prefix)) {
                    hx = [query_data[_l].pcs[xi][_i]]
                    hy = [query_data[_l].pcs[yi][_i]]
                    ht = [texts[_i]]
                    break
                }
            }
            if (hx.length) break
        }
    }
    var highlight_idx = traces.length - 1
    Plotly.restyle(pa, { x: [hx], y: [hy], text: [ht] }, [highlight_idx])
}

UPDATE_HIGHLIGHT

    # Lines from "// select listeners" through "Plotly.react(...)"
    # Also fix traces.length → traces.length - 1 in the for loop
    # Strip trailing whitespace to clean up any stray tabs in the original
    sed -n "${line_select},${line_react}p" "$INPUT" \
        | sed 's/traces\.length; i++)/traces.length - 1; i++)/' \
        | sed 's/[[:space:]]*$//'

    # Inserted: update_highlight() call after Plotly.react (blank line matches original spacing)
    printf "    update_highlight()\n\n"

    # Lines from first non-blank line after Plotly.react through to last non-blank line
    # before </script> (skips trailing blank lines — the SEARCH heredoc provides one)
    sed -n "${line_react_close},${line_script_content}p" "$INPUT"

    # Inserted: sample search block before </script>
    cat <<'SEARCH'

// sample search
var sample_list = []
for (var _label in query_data) {
    query_data[_label].text.forEach(function(t) {
        var sid = t.replace(/^sample:/, '').replace(/ ancestry-probability:.*$/, '')
        sample_list.push({ item: sid })
    })
}
sample_list.sort(function(a, b) { return a.item.localeCompare(b.item) })

var sample_search = $('#sample-search').selectize({
    plugins: ['remove_button'],
    valueField: 'item',
    labelField: 'item',
    searchField: 'item',
    options: sample_list,
    placeholder: 'Sample ID',
    mode: 'single',
    closeAfterSelect: true,
})
var sample_search_obj = sample_search[0].selectize

$('#sample-search').on('change', function() {
    update_highlight()
})

SEARCH

    # Lines from </script> to end
    tail -n +$line_script "$INPUT"

} > "$OUTPUT"

echo "Patched: $OUTPUT"
