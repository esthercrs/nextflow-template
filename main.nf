#!/usr/bin/env nextflow
/*
============================================================================
  Workflow name						                                                                                                                         
============================================================================
  Workflow description
 
  #### Homepage
  Workflow URL
 
----------------------------------------------------------------------------
*/

nextflow.enable.dsl=2

def helpMessage() {
    // Add to this help message with new command line parameters
    log.info WorkflowHeader()
    log.info"""

    Usage:

    The typical command for running the pipeline after filling the config file corresponding to your analysis as follows:

	nextflow run main.nf -profile custom

	Mandatory:
	--projectName			            [str]	    Name of the project.
	--outdir			                [path]	    The output directory where the results will be saved.

    """.stripIndent()
}

// Show help message
if (params.help) {
    helpMessage()
    exit 0
}

/*
 * SET UP CONFIGURATION VARIABLES
 */

// Has the run name been specified by the user?
//  this has the bonus effect of catching both -name and --name
custom_runName = params.name
if (!(workflow.runName ==~ /[a-z]+_[a-z]+/)) {
    custom_runName = workflow.runName
}

//Copy config files to output directory for each run
base_params_file = file("${baseDir}/conf/base.config", checkIfExists: true)
base_params_file.copyTo("${params.outdir}/00_pipeline_config/base.config")

custom_params_file = file("${baseDir}/conf/custom.config", checkIfExists: true)
custom_params_file.copyTo("${params.outdir}/00_pipeline_config/custom.config")


/*
 * PIPELINE INFO
 */

// Header log info
log.info WorkflowHeader()
def summary = [:]
if (workflow.revision) summary['Pipeline Release'] = workflow.revision
summary['Run Name'] = custom_runName ?: workflow.runName
summary['Project Name'] = params.projectName
summary['User'] = workflow.userName
summary['Launch dir'] = workflow.launchDir
summary['Working dir'] = workflow.workDir
summary['Output dir'] = params.outdir
summary['Profile'] = workflow.profile

log.info summary.collect { k,v -> "${k.padRight(42)}: $v" }.join("\n")
log.info "\033[1;34m-------------------------------------------------------------------\033[0m"

// Check the hostnames against configured profiles
checkHostname()

/*
 * VERIFY WORKFLOW VARIABLES
 */

if( params.XXX.isEmpty()) {
    log.error "ERROR: XXX have not been provided. Please check and configure the '--XXX' parameter in the custom.config file"
    exit 1
}

/*
 *  SET UP WORKFLOW CHANNELS
 */

channel
    .fromPath( params.XXX)
    .set { input_channel }

/*
 * IMPORTING MODULES
 */

include { process_name } from './modules/module_template.nf'

/*
 * RUN MAIN WORKFLOW
 */

workflow {

	/* Description of the process */
	process_name(input_channel)

}

/*
 * Completion notification
 */

workflow.onComplete {
	c_blue = "\033[1;34m";
	c_yellow = "\033[1;33m";
	c_green = "\033[1;32m";
	c_red = "\033[1;31m";
	c_reset = "\033[0m";

	if (workflow.success) {
		log.info """${c_blue}========================================================================${c_reset}
	${c_yellow}Workflow name${c_reset}: ${c_green}Pipeline completed successfully${c_reset}"""
	} else {
		checkHostname()
			log.info """${c_blue}========================================================================${c_reset}
	${c_yellow}Workflow name${c_reset}: ${c_red}Pipeline completed with errors${c_reset}"""
	}
}

/*
 * Other functions
 */

def WorkflowHeader() {
	// Log colors ANSI codes
	c_red = '\033[1;31m'
		c_blue = '\033[1;34m'
		c_reset = '\033[0m'
		c_yellow = '\033[0;33m'
		c_purple = '\033[0;35m'

		return """    ${c_blue}-----------------------------------------------------------------------------------------${c_reset}		
		${c_yellow} Workflow ASCII logo ${c_reset} 
        ${c_reset}                                                     
		${c_red}  Version: ${workflow.manifest.version}																	${c_reset}
		${c_reset}
		${c_purple}  Homepage: ${workflow.manifest.homePage}															${c_reset}
		${c_blue}-----------------------------------------------------------------------------------------${c_reset}
		""".stripIndent()
		}

		def checkHostname() {
		def c_reset = params.monochrome_logs ? '' : "\033[0m"
		def c_white = params.monochrome_logs ? '' : "\033[0;37m"
		def c_red = params.monochrome_logs ? '' : "\033[1;31m"
		def c_yellow_bold = params.monochrome_logs ? '' : "\033[1;33m"
		if (params.hostnames) {
		def hostname = "hostname".execute().text.trim()
		params.hostnames.each { prof, hnames ->
		hnames.each { hname ->
			if (hostname.contains(hname) && !workflow.profile.contains(prof)) {
				log.error "====================================================\n" +
					"  ${c_red}WARNING!${c_reset} You are running with `-profile $workflow.profile`\n" +
					"  but your machine hostname is ${c_white}'$hostname'${c_reset}\n" +
					"  ${c_yellow_bold}It's highly recommended that you use `-profile $prof${c_reset}`\n" +
					"============================================================"
			}
		}
		}
		}
		}

/*
 * Completion e-mail notification
 */
workflow.onComplete {

	// Set up the e-mail variables
	def subject = "[Workflow name] execution completed successfully!"
		if (!workflow.success) {
			subject = "[Workflow name] execution failed !"
		}
	def email_fields = [:]
		email_fields['version'] = workflow.manifest.version
		email_fields['runName'] = custom_runName
		email_fields['success'] = workflow.success
		email_fields['dateComplete'] = workflow.complete
		email_fields['duration'] = workflow.duration
		email_fields['exitStatus'] = workflow.exitStatus
		email_fields['errorMessage'] = (workflow.errorMessage ?: 'None')
		email_fields['errorReport'] = (workflow.errorReport ?: 'None')
		email_fields['commandLine'] = workflow.commandLine
		email_fields['projectDir'] = workflow.projectDir
		email_fields['summary'] = summary
		email_fields['summary']['Date Started'] = workflow.start
		email_fields['summary']['Date Completed'] = workflow.complete
		email_fields['summary']['Pipeline script file path'] = workflow.scriptFile
		email_fields['summary']['Pipeline script hash ID'] = workflow.scriptId
		if (workflow.repository) email_fields['summary']['Pipeline repository Git URL'] = workflow.repository
			if (workflow.commitId) email_fields['summary']['Pipeline repository Git Commit'] = workflow.commitId
				if (workflow.revision) email_fields['summary']['Pipeline Git branch/tag'] = workflow.revision
					email_fields['summary']['Nextflow Version'] = workflow.nextflow.version
						email_fields['summary']['Nextflow Build'] = workflow.nextflow.build
						email_fields['summary']['Nextflow Compile Timestamp'] = workflow.nextflow.timestamp

						// Check if we are only sending emails on failure     
						email_address = params.email
						if (!params.email && params.email_on_fail && !workflow.success) {
							email_address = params.email_on_fail     
						}

	// Render the TXT template
	def engine = new groovy.text.GStringTemplateEngine()
		def tf = new File("$baseDir/assets/email_template.txt") 
		def txt_template = engine.createTemplate(tf).make(email_fields)
		def email_txt = txt_template.toString()

		// Send the HTML e-mail
		if (email_address) {
			try {
				if (params.plaintext_email) { throw GroovyException('Send plaintext e-mail, not HTML') }
				// Try to send HTML e-mail using sendmail
				[ 'sendmail', '-t' ].execute() << sendmail_html
					log.info "${c_yellow}[Workflow name]${c_reset} ${c_blue} Sent summary e-mail to $email_address (sendmail)${c_reset}"
			} catch (all) {
				// Catch failures and try with plaintext
				[ 'mail', '-s', subject, email_address ].execute() << email_txt
					log.info "${c_yellow}[Workflow name]${c_reset} ${c_blue} Sent summary e-mail to $email_address (mail)${c_reset}"
			}
		}

	// Write summary e-mail HTML to a file
	def output_d = new File("${params.outdir}/01_run_info/")
		if (!output_d.exists()) {
			output_d.mkdirs()
		}
	def output_tf = new File(output_d, "execution_email.tsv")
		output_tf.withWriter { w -> w << email_txt }

}
