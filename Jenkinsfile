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
      //what event triggered this build ?
      event = new JsonSlurper().parseText("${params.payload}")['action']
      if ( new JsonSlurper().parseText("${params.payload}")['issue'] == null ) {
          event_type = 'pull_request'
          author_association = null
      } else {
          event_type = 'issue'
          author_association = new JsonSlurper().parseText("${params.payload}")['issue']['author_association']
      }

      println "This build was triggered by the $event event and $event_type event type. Look at https://developer.github.com/v3/activity/events/types for more info."

      if ( event =~ /synchronize|opened|review_requested|created/ ) {
         println "Found acceptable event $event"
      } else {
         currentBuild.result = 'ABORTED'
         error("Stopping because this build was not triggered on a PR's synchronize/opened/review_requested event which would have all the necessary information for making a build successful")
      }

      // If !deploy is created via an issue, ensure the author is a member of the org
      if ( event == 'created' && event_type == 'issue' && author_association == 'MEMBER' ){
        comment = new JsonSlurper().parseText("${params.payload}")['comment']['body']
        if ( comment != '!deploy' ){
          currentBuild.result = 'ABORTED'
          error("Stopping this build because the comment was not a recognized command.")
        }
      }

      //write payload to a file
      writeFile file: "/tmp/packer_pipeline_job_build_$BUILD_NUMBER", text: "$params.payload"

      //what is the pr number ?
      if ( event_type == 'pull_request') {
        pr = new JsonSlurper().parseText("${params.payload}")['number']
      } else if ( event_type == 'issue' ) {
        pr = new JsonSlurper().parseText("${params.payload}")['issue']['number']
      }

      if ( pr == null ) {
         currentBuild.result = 'ABORTED'
         error("Cannot build without a PR number in the payload!")
      }

      //checkout the packer-templates PR so that our script can look at the files
      dir('packer-templates') {
          git 'https://github.com/osuosl/packer-templates'
            sh "git pr $pr"
      }

      if ( event_type == 'pull_request') {
          // If this is a pull_request, grab the sha from the payload and set the GIT_COMMIT env var
          println "the GIT_COMMIT says ${env.GIT_COMMIT}"
          env.GIT_COMMIT = new JsonSlurper().parseText("${params.payload}")['pull_request']['head']['sha']
          println "the GIT_COMMIT says ${env.GIT_COMMIT}"
      }

      //pass this payload to our script so that it can return info which we can actually use
      env.payload_parsed_JSON = sh(returnStdout: true, script: """
        export PACKER_TEMPLATES_DIR=$WORKSPACE/packer-templates
        $JENKINS_HOME/bin/packer_pipeline.rb -p /tmp/packer_pipeline_job_build_$BUILD_NUMBER
      """).trim()
      writeFile file: "/tmp/${JOB_NAME}-${BUILD_NUMBER}.json", text: env.payload_parsed_JSON
   }

   /* actually starts processing the templates on the right nodes */
   stage('start_processing_on_right_nodes') {

      //some constants
      env.pr = get_from_payload('pr')
      env.event_type = get_from_payload('event_type')
      env.pr_state = get_from_payload('pr_state')

      //TODO: this should be set from the job
      //set path to the packer binary
      env.packer = '/usr/local/bin/packer'
      env.PATH = "/usr/libexec:/usr/local/bin:/opt/chef/embedded/bin:${env.PATH}"

      //TODO: this should be set from the job as an env variable
      //this should *ALWAYS* match what lib/packer_pipeline.rb return
      archs = ['x86_64', 'ppc64']

      //we will store the results here in a LinkedHashMap implementation
      def pipeline_results = readJSON text: "{}"
      writeJSON file: 'final_results.json', json: pipeline_results

      //TODO: parallelize this -- both archs can be processed seperately after all!
      for ( arch in archs ) {
         env.arch = arch
         templates = get_from_payload(env.arch)
         if ( ! templates.empty && templates != null ) {
            echo "Checking whether the node for $env.arch is actually available..."
            //check whether the node is actually up.

            try {
               timeout(time: 30, unit: 'SECONDS') {
               node(env.arch)
                  {
                     if (isUnix()) {
                     echo "Yep, the node is up and is a *nix node!"
                     }
                     else {
                        echo "Node for $env.arch is not a *nix node! Going to skip it"
                        throw new Exception("Node for $env.arch is not a *nix node! Going to skip it")
                     }
                  }
               }
            } catch (err) {
               echo "Caught an error '${err}' while trying to acess node for ${arch}"
               echo "Marking all templates for ${env.arch} as un-processable!"
               mark_templates_as_unprocessable(env.arch, 127)
               node_results = readJSON file: "${arch}_results.json"
               update_final_results(arch, node_results)
               continue
               echo "Skipping to next arch!"
            }

            echo "Starting execution for $env.arch"
            //do actual things on the node.
            node (env.arch) {
               // We've already done a sanity check before this, so if this is an issue type, we know !deploy was used
               if( env.event_type == 'issue') {
                 if( env.pr_state == 'success') {
                   deploy_image_on_production(env.arch)
                 } else {
                   currentBuild.result = 'ABORTED'
                   error("PR in state ${env.pr_state}. Not deploying")
                 }

               }
               else{
                 clone_repo_and_checkout_pr_branch()
                 run_linter(env.arch)
                 build_image(env.arch)
                 deploy_image_for_testing(env.arch)
                 run_tests(env.arch)
                 //archive '*' //store all the files
                 node_results = readJSON file: "${arch}_results.json"
                 deleteDir()
                 //TODO: delete the directory if this build succeeds complteley
               }
             }
             update_final_results(arch, node_results)
         }
         else
         {
            echo "No templates for $env.arch!"
         }
      }

      if( env.event_type == 'pull_request' ) {
          // set status on the commit using the PackerPipeline class
          withCredentials([usernamePassword(
                credentialsId: 'packer_pipeline',
                usernameVariable: '',
                passwordVariable: 'GITHUB_TOKEN')]) {
             //available as an env variable
             sh 'echo "$GITHUB_TOKEN should appear as masked and not null"'
             result = sh(returnStdout: true, script: """
                  cat $WORKSPACE/final_results.json;
                   $JENKINS_HOME/bin/packer_pipeline.rb -f $WORKSPACE/final_results.json
             """)
             echo result
          }
      } else if( env.event_type == 'issue' ) {
          // Merge and delete branch
          withCredentials([usernamePassword(
                credentialsId: 'packer_pipeline',
                usernameVariable: '',
                passwordVariable: 'GITHUB_TOKEN')]) {
             // available as an env variable
             sh 'echo "$GITHUB_TOKEN should appear as masked and not null"'
             result = sh(returnStdout: true, script: """
                   $JENKINS_HOME/bin/packer_pipeline.rb -d ${env.pr}
             """)
             echo result
          }
      }
   }
}
/* update_final_results(arch, node_results)

   appends the given node results to the results.json file on the master node for the arch
*/

def update_final_results(arch, rs) {

   final_results = readJSON file: 'final_results.json'
   echo "Final results are $final_results and we are going to add $rs to it"
   final_results.accumulate(arch, rs)
   echo "Now final results are $final_results"
   writeJSON file: 'final_results.json', json: final_results
}


/*
update_template_result(arch, template_name, stage, result)

   updates the results of a given stage for a given template in the
   global pipeline_results array for a given architecture

   result can be either true or false

   does not validate the template_name OR the stage  OR the the result
*/

def update_template_result(arch, t, stage, result) {
   //TODO: enclose in a try-catch block
   json_file = "${arch}_results.json"
   try {
      pipeline_results = readJSON file: json_file
   }
   catch (java.io.FileNotFoundException e) {
      echo "$json_file does not exist on $NODE_NAME. Creating it..."
      pipeline_results = readJSON text: "{}"
   }
   finally {
      echo "Updating result of $stage for $t as $result in $pipeline_results"
      if ( ! (t in pipeline_results.keySet()) ) {
         //if the template hasn't been already included in results, create an entry for it
         pipeline_results."$t" = [:]
      }
      //store the result after converting toString() because apparently
      //sometimes returnStatus gives us an object!

      pipeline_results[t]."$stage" = result.toString()
   }

   writeJSON file: json_file, json: pipeline_results
}

/*
check_template_result(template_name, stage)
   tells what was the result of a stage on a given template
   template_name is a string
   stage is one of ['node_state', 'linter','builder','deploy_test','taster', 'publish']

   if a stage does not exist (which might mean that the template never went through the state)
   we will simply return false

   NOTE: This will convert the 0 exit status to True and anything non-zero to false before returning

*/
def check_template_result(arch, t, stage) {
   pipeline_results = readJSON file: "${arch}_results.json"
   echo "We have $pipeline_results"
   try {
      r = pipeline_results[t][stage]
      echo "$stage had the exit status of $r for template $t"

      //remember, we are comparing string representation of the exit status
      if ( r == "0" || r == "true" ) {
         return true
      }
      else {
         return false
      }
   }
   catch(Exception e) {
      println e
      return false
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

/* mark_templates_as_unprocessable(arch)

   This marks all templates for a given arch as un-processable

   This might happen in cases when the node designated to process template is
   either in an error state or is simply unavailable.
*/
def mark_templates_as_unprocessable(arch, error_code = 127) {
   def templates = get_from_payload(arch)
   for ( t in templates ) {
      update_template_result(arch, t, 'node_state', error_code)
      println "Marked $t as $error_code for node state"
   }
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
          result = sh (returnStatus: true, script: "$env.packer validate -syntax-only $t")
          update_template_result(arch, t, 'linter', result)
          println "processed $t as $result"
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
         //check whether this template passed linting and that it was not already built!
         if ( check_template_result(arch, t, 'linter') && !check_template_result(arch, t, 'builder') ) {
            result = sh (returnStatus: true, script: "./bin/build_image.sh -t $t")
            update_template_result(arch, t, 'builder', result)
         }
         else {
            println "Skipping $t because it did not pass the linter"
         }
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
      for ( t in templates ) {
         //check whether this template was successfully built into an image and it was not already deployed!
         if ( check_template_result(arch, t, 'builder') && !check_template_result(arch, t, 'deploy_test' ) ) {
            result = sh (returnStatus: true, script: "./bin/deploy_wrapper.rb -d raw -t $t -s /home/alfred/openstack_credentials.json -r $env.pr")
            update_template_result(arch, t, 'deploy_test', result)
         } else {
            println "Skipping $t because it was not successfully built!"
         }
      }
   }
   templates = null
}

/* deploy_image_on_production(arch)

   deploys qcow2 images on the various clusters for the given arch.
   cluster credentials come from packer_pipeline_credentials.json
   in alfred's home

   TODO: failure while deploying any image is a soft failure
*/
def deploy_image_on_production(arch) {
   def templates = get_from_payload(arch)
   stage('deploy_publically') {
      for ( t in templates ) {
        result = sh (returnStatus: true, script: "./bin/deploy_wrapper.rb -d raw -t $t -s /home/alfred/openstack_credentials.json -r $env.pr -p")
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
         if ( check_template_result(arch, t, 'deploy_test') && !check_template_result(arch, t, 'taster')) {
            result = sh (returnStatus: true, script: "./bin/taster_wrapper.rb -t $t -s /home/alfred/openstack_credentials.json -r $env.pr")
            update_template_result(arch, t, 'taster', result)
         } else {
            println  "Not tasting $t because it was not successfully deployed"
         }
      }
   }
   templates = null
}
