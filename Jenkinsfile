// CI pipeline for demo-app
//   PR builds:   tests -> SonarQube + quality gate -> docker build -> Trivy image gate
//   main builds: the same + push to ECR + update the image tag in aws-platform-gitops

pipeline {
    agent any

    options {
        disableConcurrentBuilds()
        timestamps()
        buildDiscarder(logRotator(numToKeepStr: '20'))
    }

    environment {
        AWS_REGION   = 'eu-central-1'
        ECR_REGISTRY = '958317380912.dkr.ecr.eu-central-1.amazonaws.com'
        IMAGE        = '958317380912.dkr.ecr.eu-central-1.amazonaws.com/demo-app'
        GITOPS_REPO  = 'github.com/ShivaAdigoppula/aws-platform-gitops.git'
    }

    stages {

        stage('Set image tag') {
            steps {
                script {
                    env.IMAGE_TAG = env.GIT_COMMIT.take(7)      // e.g. a1b2c3d
                    echo "Image tag: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Unit tests') {
            steps {
                // Same Python as the Dockerfile; runs as the jenkins user, at the same path as on the host
                sh '''
                  docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
                    -v "$PWD":"$PWD" -w "$PWD" python:3.12-slim \
                    sh -c "pip install -q --user -r requirements.txt -r requirements-dev.txt && \
                           python -m pytest -v --cov=app --cov-report=xml --junitxml=test-results.xml"
                '''
            }
            post {
                always { junit allowEmptyResults: true, testResults: 'test-results.xml' }
            }
        }

        stage('SonarQube analysis') {
            steps {
                script {
                    def scannerHome = tool 'sonar-scanner'
                    withSonarQubeEnv('sonarqube') {
                        sh "${scannerHome}/bin/sonar-scanner"
                    }
                }
            }
        }

        stage('Quality gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true      // fails the build if the gate fails
                }
            }
        }

        stage('Docker build') {
            steps {
                sh 'docker build --pull --build-arg APP_VERSION=$IMAGE_TAG -t $IMAGE:$IMAGE_TAG .'
            }
        }

        stage('Trivy image scan (gate)') {
            steps {
                sh 'trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 --no-progress $IMAGE:$IMAGE_TAG'
            }
        }

        stage('Push to ECR') {
            when { branch 'main' }
            steps {
                sh '''
                  aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
                  if aws ecr describe-images --repository-name demo-app --image-ids imageTag=$IMAGE_TAG --region $AWS_REGION > /dev/null 2>&1; then
                    echo "Tag $IMAGE_TAG already exists in ECR (tags are immutable) - skipping push"
                  else
                    docker push $IMAGE:$IMAGE_TAG
                  fi
                '''
            }
        }

        stage('Update GitOps repo') {
            when { branch 'main' }
            steps {
                withCredentials([usernamePassword(credentialsId: 'gitops-token',
                                                  usernameVariable: 'GIT_USER',
                                                  passwordVariable: 'GIT_TOKEN')]) {
                    sh '''
                      rm -rf gitops
                      git clone --depth 1 https://x-access-token:${GIT_TOKEN}@${GITOPS_REPO} gitops
                      cd gitops
                      sed -i "s|newTag: .*|newTag: ${IMAGE_TAG}|" manifests/demo-app/kustomization.yaml
                      git config user.name  "jenkins-ci"
                      git config user.email "jenkins-ci@users.noreply.github.com"
                      git add manifests/demo-app/kustomization.yaml
                      if git diff --cached --quiet; then
                        echo "Tag is already ${IMAGE_TAG} - nothing to commit"
                      else
                        git commit -m "deploy(demo-app): ${IMAGE_TAG}"
                        git push origin HEAD:main
                      fi
                    '''
                }
            }
        }
    }

    post {
        always {
            // Keep the Jenkins disk from filling up with images
            sh 'docker rmi $IMAGE:$IMAGE_TAG || true'
            sh 'docker image prune -f || true'
        }
    }
}