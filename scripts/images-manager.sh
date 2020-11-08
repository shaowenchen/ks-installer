#!/bin/bash

#!/usr/bin/env bash

# Copyright 2018 The KubeSphere Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ImagesListDefault="kubesphere-images.txt"
ImagesDirDefault=$(cd "$(dirname "$0")" || exit;pwd)/kubesphere-images
save="false"
registryurl=""
reposUrl=("quay.azk8s.cn" "gcr.azk8s.cn" "docker.elastic.co" "quay.io" "k8s.gcr.io")

func() {
    echo "Usage:"
    echo
    echo "  $0 [-l IMAGES-LIST] [-d IMAGES-DIR] [-r PRIVATE-REGISTRY]"
    echo
    echo "Description:"
    echo "  -d IMAGES-DIR        : the dir of files (tar.gz) which generated by \`docker save\`. default: ${ImagesDirDefault}"
    echo "  -s                   : save model will be applied.Pull the images in the IMAGES-LIST and save images as a tar.gz file."
    echo "  -l IMAGES-LIST       : text file with list of images. default: ${ImagesListDefault}"
    echo "  -r PRIVATE-REGISTRY  : target private registry:port."
    echo "  -h                   : usage message"
    exit
}

while getopts 'sl:r:d:h' OPT; do
    case $OPT in
        l) ImagesList="$OPTARG";;
        r) Registry="$OPTARG";;
        d) ImagesDir="$OPTARG";;
        s) save="true";;
        h) func;;
        ?) func;;
        *) func;;
    esac
done

if [ -z "${ImagesList}" ]; then
    ImagesList=${ImagesListDefault}
fi

if [ -z "${ImagesDir}" ]; then
    ImagesDir=${ImagesDirDefault}
fi

if [ -n "${Registry}" ]; then
   registryurl=${Registry}
fi

if [ ${save} == "true" ]; then
    if [ ! -d ${ImagesDir} ]; then
       mkdir -p ${ImagesDir}
    fi
    ImagesListLen=$(cat ${ImagesList} | wc -l)
    name=""
    images=""
    index=0
    for image in $(<${ImagesList}); do
        if [[ ${image} =~ ^\#\#.* ]]; then
           if [[ -n ${images} ]]; then
              echo ""
              echo "Save images: "${name}" to "${ImagesDir}"/"${name}".tar.gz  <<<"
              docker save ${images} | gzip -c > ${ImagesDir}"/"${name}.tar.gz
              echo ""
           fi
           images=""
           name=$(echo "${image}" | sed 's/#//g' | sed -e 's/[[:space:]]//g')
           ((index++))
           continue
        fi

        docker pull "${image}"
        images=${images}" "${image}

        if [[ ${index} -eq ${ImagesListLen}-1 ]]; then
           if [[ -n ${images} ]]; then
              docker save ${images} | gzip -c > ${ImagesDir}"/"${name}.tar.gz
           fi
        fi
        ((index++))
    done
else
    # shellcheck disable=SC2045
    for image in $(ls ${ImagesDir}/*.tar.gz); do
      echo "Load images: "${image}"  <<<"
      docker load  < $image
    done

    if [[ -n ${registryurl} ]]; then
       for image in $(<${ImagesList}); do
          if [[ ${image} =~ ^\#\#.* ]]; then
             continue
          fi
          url=${image%%/*}
          ImageName=${image#*/}
          echo $image

          if echo "${reposUrl[@]}" | grep -w "$url" &>/dev/null; then
            imageurl=$registryurl"/"${image#*/}
          elif [ $url == $registryurl ]; then
              if [[ $ImageName != */* ]]; then
                 imageurl=$registryurl"/library/"$ImageName
              else
                 imageurl=$image
              fi
          elif [ "$(echo $url | grep ':')" != "" ]; then
              imageurl=$registryurl"/library/"$image
          else
              imageurl=$registryurl"/"$image
          fi

          ## push image
          echo $imageurl
          docker tag $image $imageurl
          docker push $imageurl
       done
    fi
fi
