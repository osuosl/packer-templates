#!groovy
import groovy.json.JsonSlurper

node {
   stage('payload_processing') { 
      //git 'https://github.com/osuosl-cookbooks/osl-jenkins'
    
      //write payload to a file
      writeFile file: "/tmp/packer_pipeline_job_build_$BUILD_NUMBER", text: "$params.payload"
    
      //pass this output to our script
      env.payload_parsed_JSON = sh(returnStdout: true, script: """ 
        export PACKER_TEMPLATES_DIR=$WORKSPACE
        cat /tmp/packer_pipeline_job_build_$BUILD_NUMBER | /tmp/osl-jenkins/files/default/bin/packerpipeline.rb
      """).trim()
      writeFile file: "/tmp/${JOB_NAME}-${BUILD_NUMBER}.json", text: env.payload_parsed_JSON
   }   

   stage('start_builds_on_right_nodes') {  
      x86_templates = get_from_payload('x86_64')
      ppc64_templates = get_from_payload('pp64')
      pr = get_from_payload('pr')

      //set path to the packer binary
      env.packer = '~/bin/packer'

      //lets worry about only a single branch of workflow and a single arch for now.
      println data['ppc64']
      
      //def templates = data.x86_64
      for ( arch in data.keySet() ) {
          echo "Starting execution for $arch"
          //do following things on the node.
           
          node (label:arch) {
            clone_repo_and_checkout_pr_branch()
            run_linter()
            build_image()
            deploy_image_for_testing()
            run_tests()
            //deploy_on_production() -- seperate!
          }
      }
      
      //unset everything we don't need (and can't serialize)
      jsonSlurper = null
      data = null
   }
}

def get_from_payload(v) {
   def jsonSlurper = new JsonSlurper()
   def data = jsonSlurper.parseText("${payload_parsed_JSON}")

   if ( data.containsKey(v) ) {
      r = data[v]
   }
   else {
      r = data
   }
   println "Returning $r"
   return r
}

def clone_repo_and_checkout_pr_branch() {
   //checkout all templates
   git 'https://github.com/osuosl/packer-templates'
   dir 'packer-templates'
   sh "git pr $env.pr"
}

def run_linter(templates) {
   //run linter

   for ( t in templates ) {
      sh (returnStdout: true, script: "$env.packer validate $t")
   }
}

def build_image(templates) {
   dir 'packer-templates'

   //TODO: this will go in a try-catch block
   for ( t in templates ) {
      sh (returnStatus: true, script: "./bin/build_image.sh -t $t")
   }
}

def deploy_image_for_testing(templates) {
   //do for each openstack_environment

   dir 'packer-templates'

   //deploy!
   for ( t in templates ) {
      image_name = "packer-$t".replace('.json','')
      image_path = "./$image_name/${image_name}.qcow2"
      sh (returnStdout: true, script: "./bin/deploy.sh -f $image_path -r $env.pr")
   }
}

def run_tests() {
   //run wrapper_script

   dir 'packer_templates'

   // TODO: put this in try-catch
   for ( t in templates ) {
      image_name = sh (returnStdout: true, script: "./bin/wrapper.sh $t -f image_name")
      sh (returnStdout: true, script: "openstack_taster $image_name")
   }
}

