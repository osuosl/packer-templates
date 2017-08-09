#!groovy
import groovy.json.JsonSlurper

/*
receive, store, process and actually call the right jenkin nodes
to process the template files based on the architecture

everything runs on whatever is labeled as 'master'

*/

node ('master'){
   /* receives the payload, parses it and gets us the PR number, templates to process and arch */
   stage('payload_processing') {

      //clone the osl-jenkins on master branch to use the latest version of scripts
      git url: 'https://github.com/osuosl-cookbooks/osl-jenkins', branch: 'master'
    
      //write payload to a file
      writeFile file: "/tmp/packer_pipeline_job_build_$BUILD_NUMBER", text: "$params.payload"

      //what is the pr number ?
      pr = new JsonSlurper().parseText("${params.payload}")['number']

      //checkout the packer-templates PR so that our script can look at the files
      dir('packer-templates') {
          git 'https://github.com/osuosl/packer-templates'
            sh "git pr $pr"
      }

      //pass this payload to our script so that it can return info which we can actually use
      env.payload_parsed_JSON = sh(returnStdout: true, script: """
        export PACKER_TEMPLATES_DIR=$WORKSPACE/packer-templates
        cat /tmp/packer_pipeline_job_build_$BUILD_NUMBER | $WORKSPACE/files/default/bin/packer_pipeline.rb
      """).trim()
      writeFile file: "/tmp/${JOB_NAME}-${BUILD_NUMBER}.json", text: env.payload_parsed_JSON
   }

   /* actually starts processing the templates on the right nodes */
   stage('start_processing_on_right_nodes') {

      env.pr = get_from_payload('pr')
      

      //TODO: this should be set from the job
      //set path to the packer binary
      env.packer = '/usr/local/bin/packer'
      env.PATH = "/usr/libexec:/usr/local/bin:/opt/chef/embedded/bin:${env.PATH}"

      //TODO: this should be set from the job as an env variable
      //this should *ALWAYS* match what lib/packer_pipeline.rb return
      archs = ['x86_64', 'ppc64']

      //TODO: parallelize this -- both archs can be processed seperately after all!
      for ( arch in archs ) {
         env.arch = arch
         templates = get_from_payload(env.arch)
         if ( ! templates.empty && templates != null ) {
             echo "Starting execution for $env.arch"
             //do following things on the node.
             node (env.arch) {
               clone_repo_and_checkout_pr_branch()
               run_linter(env.arch)
               build_image(env.arch)
               deploy_image_for_testing(env.arch)
               run_tests(env.arch)
               archive '*'
               //deploy_on_production() -- seperate!
             }
         }
         else
         {
            echo "No templates for $env.arch!"
         }
      }
   }
}

/*
get_from_payload(variable_name) :
   read the parsed payload JSON from the disk
   and return variables in a form that's easy to process

   this always runs on the master.

Why do we need this function?
-----------------------------

Jenkins requires any variable to be serializable so that
even if the master is restarted, the state is maintained.
A JSON object in memory is represented as a Map which does not
implement the Serializable interface.

So we implement our own "serializer-deserializer" in this manner.
*/
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


// clone the packer-templates repo and checkout the branch which we want to use
def clone_repo_and_checkout_pr_branch() {
   stage('clone_repo_and_checkout_pr_branch') {
       //checkout all templates
       git 'https://github.com/osuosl/packer-templates'
          sh "git pr $env.pr"
   }
}

/* run_linter(arch)

   run linter on each template of the given architecture

   #TODO: failure in any template is a hard failure.
*/
def run_linter(arch) {
   def templates = get_from_payload(arch)
   //run linter
   stage('linter') {
       for ( t in templates ) {
          sh (returnStdout: true, script: "$env.packer validate -syntax-only $t")
       }
   }

   // remove this line and you shall get an error. why ? because templates is non-serializable
   // and anything left unserialized is bad!
   templates = null
}

/* build_image(arch)

   builds deployable qcow2 images for templates of the given arch

   #TODO: failure to build a single image should be a hard failure
*/
def build_image(arch) {
   def templates = get_from_payload(arch)
   stage('build_image') {
      for ( t in templates ) {
         sh (returnStdout: true, script: "./bin/build_image.sh -t $t")
      }
   }
   templates = null
}

/* deploy_image_for_testing(arch)

   deploys qcow2 images on the various clusters for the given arch.
   cluster credentials come from packer_pipeline_credentials.json
   in alfred's home

   TODO: failure while deploying any image is a soft failure
*/
def deploy_image_for_testing(arch) {
   def templates = get_from_payload(arch)
   stage('deploy_for_testing') {
   //deploy!
      for ( t in templates ) {
         deploy_output = sh (returnStdout: true, script: "./bin/deploy_wrapper.rb -t $t -s /home/alfred/openstack_credentials.json -r $env.pr")
         println deploy_output
      }
   }
   templates = null
}

/* run_tests(arch)

   runs tastes using openstack_taster on all deployed images of a given arch.

   this function takes a template, deciphers the name with which it would have been deployed,
   and runs the test suites against that image name.

   TODO: failure while tasting any image is a hard failure.
*/

def run_tests(arch) {
   def templates = get_from_payload(arch)
   //run wrapper_script
   stage('openstack_taster') {
      // TODO: put this in try-catch
      for ( t in templates ) {
         taste_output = sh (returnStdout: true, script: "./bin/taster_wrapper.rb -t $t -s /home/alfred/openstack_credentials.json -r $env.pr").trim()
         println taste_output
      }
   }
   templates = null
}
