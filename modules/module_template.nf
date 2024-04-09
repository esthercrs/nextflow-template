process process_name {

    label 'label_name'
    tag "${id}"
    
    publishDir "${params.outdir}/${params.report_dirname}/[step_name]", mode: 'copy', pattern: ''

    input:

    output:


    script:
    """
    script_template.sh args1 args2 ... completecmd >& process_name.log 2>&1
    """

}