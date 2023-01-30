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
	sh 'make jammy_package EXOSCALE_DOCKER_REGISTRY=${EXOSCALE_DOCKER_REGISTRY}'
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
