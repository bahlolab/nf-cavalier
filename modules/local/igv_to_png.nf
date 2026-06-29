
process IGV_TO_PNG {
    label 'C2M8T2'
    label 'puppeteer'
    maxForks 25
    tag "$fam"
    //beforeScript "mkdir -p home"
    //containerOptions "--overlay \"\$PWD/home\":/home/pptruser"
    containerOptions '--writable-tmpfs'
    /*
        - Generate PNGs for igv-report
    */

      input:
    tuple val(fam), path(reports)

    output:
    tuple val(fam), path("*.png")

    script:
    def width = 600
    def height = 800
    def scale = 3

    cmds = reports.collect{
      def id = (it.name =~ /igv_report\.(.*?)\.html/)[0][1]
      "export_igv_png.js $it SID_${id}.VID_ $width $height $scale"
    }.join('\n')

"""
export NODE_PATH=/home/pptruser/node_modules
export HOME=/home/pptruser/
$cmds
"""
}