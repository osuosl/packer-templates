#!groovy
import groovy.json.JsonSlurper

node 'master' {
   stage('payload_processing') { 
      //git 'https://github.com/osuosl-cookbooks/osl-jenkins'
    
      //write payload to a file
      writeFile file: "/tmp/packer_pipeline_job_build_$BUILD_NUMBER", text: "$params.payload"
    
      //pass this output to our script
      payload_parsed_JSON = sh(returnStdout: true, script: """ 
        export PACKER_TEMPLATES_DIR=$WORKSPACE
        cat /tmp/packer_pipeline_job_build_$BUILD_NUMBER | /tmp/osl-jenkins/files/default/bin/packerpipeline.rb
      """).trim()
      writeFile file: "/tmp/${JOB_NAME}-${BUILD_NUMBER}.json", text: "$payload_parsed_JSON"
   }   

   stage('start_builds_on_right_nodes') {  
      def jsonSlurper = new JsonSlurper()
      def data = jsonSlurper.parseText("${payload_parsed_JSON}")
      
      env.pr = data['pr']
      /* if ( data.containsKey('ppc64') ) {
          println "We are going to call ppc64 node with ${data['ppc64']}"
          env.ppc64_templates_affected = data.ppc64
      }
      
      if ( data.containsKey('x86_64') ) {
          env.x86_64_templates_affected = data.x86_64
          println "We are going to call x86_64 node with ${data['x86_64']}"
      }*/

   }
}

def linter() {
   //checkout all templates
   git 'https://github.com/osuosl/packer-templates'
   dir 'packer-templates'
   sh "git pr $env.pr"
    
   sh "~/bin/packer validate 
}
