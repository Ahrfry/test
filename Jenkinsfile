#!groovy

/*
 * Copyright (c) 2016-2017 Haggai Eran, Gabi Malka, Lior Zeno, Maroun Tork
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 *  * Redistributions of source code must retain the above copyright notice, this
 * list of conditions and the following disclaimer.
 *  * Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation and/or
 * other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS ``AS IS''
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

def ikernels=['passthrough', 'threshold', 'cms', 'pktgen', 'echo', 'memcached']

properties ([parameters([
    choice(name: 'VIVADO_VERSION',
           description: 'The version of Vivado HLS to use for the build',
           choices: ['2016.2', '2016.4', '2017.2'].join('\n')),
    string(name: 'MEMCACHED_CACHE_SIZE', defaultValue: '4096', description: 'Memcached cache size in entries'),
    string(name: 'MEMCACHED_KEY_SIZE', defaultValue: '10', description: 'Memcached key size in bytes'),
    string(name: 'MEMCACHED_VALUE_SIZE', defaultValue: '10', description: 'Memcached value size in bytes'),
])])

def build_hls_project(build_dir, project, simulation) {
    def target = simulation ? "${project}-sim" : "${project}"
    if (simulation) {
        echo "Running HLS RTL/C cosimulation for project ${project}."
    } else {
        echo "Running HLS synthesis for project ${project}."
    }
    dir("nica/$build_dir") {
        sh vivadoEnv() + """
        make ${target}
        """
    }
    if (simulation) {
        archiveArtifacts "nica/$build_dir/${project}-sim/40Gbps/syn/report/*"
        archiveArtifacts "nica/$build_dir/${project}-sim/40Gbps/sim/report/*"
    } else {
        archiveArtifacts "nica/$build_dir/${project}/40Gbps/syn/report/*"
        archiveArtifacts "nica/$build_dir/${project}/40Gbps/impl/ip/**/*"
    }
    archiveArtifacts "nica/$build_dir/${project}/40Gbps/40Gbps.log"
}

def hls(build_dir, project) {
    try {
        build_hls_project(build_dir, project, false)
        build_hls_project(build_dir, project, true)
    } catch (Exception err) {
        echo "Error: Exception ${err}"
        currentBuild.result = 'FAILURE'
    }
}

def findCmake() {
    if (fileExists('/usr/bin/cmake3'))
        return '/usr/bin/cmake3'
    return 'cmake'
}

def vivadoEnv() {
    return ". /opt/Xilinx/Vivado/${params.VIVADO_VERSION}/settings64.sh ;"
}

node {
    def GTEST_ROOT=pwd() + '/googletest/googletest'
    def CMAKE=findCmake()

    stage('Preparation') {
        // Fetch our code
        dir('nica') {
            // the HLS project
            // This credential allows read-only to haggai's bitbucket
            // Pull request build
            checkout scm
        }
        dir ('libvma') {
            // libvma is needed to build the host apps
            git credentialsId: '336fdc5e-b4a2-47dc-adde-ce4343484399', url:
            'git@bitbucket.org:haggai_e/libvma.git', branch: 'nica'
        }

        dir ('googletest') {
            // Google test for the HLS ikernel tests and NICA tests
            git 'https://github.com/google/googletest'
            // Build googletest (without googlemock)
            sh """cd googletest
            $CMAKE -DBUILD_GMOCK=OFF -DBUILD_GTEST=ON .
            make -j"""
        }
        dir('libvma') {
            // Build libvma, pointing it to the HLS repository for its headers
            withEnv(["ACLOCAL_PATH=/usr/share/aclocal"]) {
                sh '''
                ./autogen.sh
                ./configure IKERNEL_PATH=`pwd`/../nica
                make -j
                '''
            }
        }
        dir('nica/build') {
            // Build the HLS repository (host part only)
            // One ikernel
            sh """
            rm -f CMakeCache.txt
            $CMAKE \
                -DNICA_DIR=`pwd`/../../libvma/src/nica \
                -DVMA_DIR=`pwd`/../../libvma/src \
                -DGTEST_ROOT=${GTEST_ROOT} \
                -DXILINX_VIVADO_VERSION=${params.VIVADO_VERSION} \
                -DNUM_IKERNELS=1 \
                -DMEMCACHED_CACHE_SIZE=${params.MEMCACHED_CACHE_SIZE} \
                -DMEMCACHED_KEY_SIZE=${params.MEMCACHED_KEY_SIZE} \
                -DMEMCACHED_VALUE_SIZE=${params.MEMCACHED_VALUE_SIZE} \
                ..
            make -j
            """
        }
        //dir('nica/build-2') {
        //    // Build the HLS repository (host part only)
        //    // Two ikernels
        //    sh """
        //    $CMAKE \
        //        -DNICA_DIR=`pwd`/../../libvma/src/nica \
        //        -DVMA_DIR=`pwd`/../../libvma/src \
        //        -DGTEST_ROOT=${GTEST_ROOT} \
        //        -DNUM_IKERNELS=2 \
        //        ..
        //    make -j
        //    """
        //}
    }
    stage('Tests') {
        dir('nica/build') {
            // Run HLS unit tests (C simulation)
            sh '''
            make -j check
            '''
        }
    }
    def branches = [
        nica: {
            stage('NICA NUM_KERNELS=1') {
                hls('build/nica', 'nica')
            }
            //stage('NICA NUM_KERNELS=2') {
            //    hls('build-2/nica', 'nica')
            //}
        },
        ikernels: {
            for (ikernel in ikernels) {
                stage(ikernel) {
                    hls('build/ikernels', ikernel)
                }
            }
        }
    ]
    currentBuild.result = 'SUCCESS'
    parallel branches
}

if (env.BRANCH_NAME == 'master' && currentBuild.result == 'SUCCESS') {
    build job: 'netperf-verilog/master', parameters: [
        string(name: 'BUILD_NUM', value: env.BUILD_NUMBER),
        string(name: 'NETPERF_HW_BRANCH', value: env.BRANCH_NAME),
        string(name: 'IKERNEL0', value: 'threshold')
    ], wait: false
}
if (currentBuild.result == 'SUCCESS') {
    build job: "nica-implementation/${env.BRANCH_NAME}", parameters: [
        string(name: 'BUILD_NUM', value: env.BUILD_NUMBER),
        string(name: 'NETPERF_HW_BRANCH', value: env.BRANCH_NAME),
        string(name: 'IKERNEL0', value: 'threshold')
    ], wait: false
}

color = 'warning'
if (currentBuild.result == 'SUCCESS')
    color = 'good'
slackSend color: color, message: "Build ${env.JOB_NAME} ${env.BUILD_NUMBER} (<${env.BUILD_URL}|${env.BUILD_NUMBER}> completed: result = ${currentBuild.result})"
