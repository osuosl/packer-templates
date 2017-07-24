#!groovy
import groovy.json.JsonSlurper

node ('master'){
   stage('payload_processing') { 
      git url: 'https://github.com/osuosl-cookbooks/osl-jenkins', branch: 'samarendra/bento_pipeline'
    
      //write payload to a file
      writeFile file: "/tmp/packer_pipeline_job_build_$BUILD_NUMBER", text: "$params.payload"
    
      //pass this output to our script
      env.payload_parsed_JSON = sh(returnStdout: true, script: """ 
        export PACKER_TEMPLATES_DIR=$WORKSPACE
        cat /tmp/packer_pipeline_job_build_$BUILD_NUMBER | $WORKSPACE/files/default/bin/packer_pipeline.rb
      """).trim()
      writeFile file: "/tmp/${JOB_NAME}-${BUILD_NUMBER}.json", text: env.payload_parsed_JSON
   }   

   stage('start_builds_on_right_nodes') {  
      //set path to the packer binary
      env.packer = '~/bin/packer'
      env.pr = get_from_payload('pr')
      
      x86_64_templates = get_from_payload('x86_64')
      if ( x86_64_templates != null ) {
          echo "Starting execution for x86_64"
          
          //do following things on the node.
          node ('x86_64') {
            clone_repo_and_checkout_pr_branch()
            run_linter()
            build_image()
            deploy_image_for_testing()
            run_tests()
            //deploy_on_production() -- seperate!
          }
      }
      
      ppc64_templates = get_from_payload('ppc64')
      if ( ppc64_templates != null ) {
          echo "Starting execution for ppc64"
          
          //do following things on the node.
          node ('ppc64') {
            clone_repo_and_checkout_pr_branch()
            run_linter()
            build_image()
            deploy_image_for_testing()
            run_tests()
            //deploy_on_production() -- seperate!
          }
      }
      
   }
}

def get_from_payload(v) {
   def jsonSlurper = new JsonSlurper()
   def data = jsonSlurper.parseText("${payload_parsed_JSON}")

   if ( data.containsKey(v) ) {
      r = data[v]
   }
   else {
      r = null
   }
   println "Returning $r"
   return r
}

def clone_repo_and_checkout_pr_branch() {
   stage('clone_repo_and_checkout_pr_branch') {
       //checkout all templates
       git 'https://github.com/osuosl/packer-templates'
       dir 'packer-templates'
       sh "git pr $env.pr"
   }
}

def run_linter(templates) {
   //run linter
   stage('linter') {
       for ( t in templates ) {
          sh (returnStdout: true, script: "$env.packer validate $t")
       }
   }
}

def build_image(templates) {
   dir 'packer-templates'

   //TODO: this will go in a try-catch block
   stage('build_image') {
      for ( t in templates ) {
         sh (returnStatus: true, script: "./bin/build_image.sh -t $t")
      }
   }
}

def deploy_image_for_testing(templates) {
   //do for each openstack_environment
   stage('deploy_for_testing') {
      dir 'packer-templates'

      //deploy!
      for ( t in templates ) {
         image_name = "packer-$t".replace('.json','')
         image_path = "./$image_name/${image_name}.qcow2"
         sh (returnStdout: true, script: "./bin/deploy.sh -f $image_path -r $env.pr")
      }
   }
}

def run_tests() {
   //run wrapper_script
   stage('openstack_taster') {
      dir 'packer_templates'

      // TODO: put this in try-catch
      for ( t in templates ) {
         image_name = sh (returnStdout: true, script: "./bin/wrapper.sh $t -f image_name")
         sh (returnStdout: true, script: "openstack_taster $image_name")
      }
   }
}

