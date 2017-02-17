#!/bin/sh
red="\x1B[0;31m"
green="\x1B[0;32m"
yellow="\x1B[0;33m"
endColor="\x1B[0m"
underline="\x1B[4m"
endUnderline="\x1B[24m"

help="${underline}Usage:${endUnderline}\n\
./$(basename "$0")\n\n\
${underline}Options:${endUnderline}\n\
${yellow}-s|--specs${endColor}      Specifies name of specs branch. Default: -s specs.\n\
${yellow}-l|--libraries${endColor}  If set, pod is building with --use-libraries parameter.\n\
${yellow}-v|--verbose${endColor}    Shows extended content on console output.\n\
${yellow}-h|--help${endColor}       Displays this info.\n\n"

spec_branch_name="specs"
use_libraries=""
verbosed=""

#init parameters form arguments
while test $# -gt 0; do
    case "$1" in
        -s|--specs)
        spec_branch_name="$2"
        shift #past argument
        ;;

        -l|--libraries)
        use_libraries="--use-libraries"
        shift #past argument
        ;;

        -v|--verbose)
        verbosed="--verbose"
        shift #past argument
        ;;

        -h|--help)
        echo "$help"
        exit 0
        ;;

        *)
        echo "${red}Unknown ${1} option.${endColor}"
        shift #past argument
        ;;

        --default)
        ;;
        esac
done

current_branch=$(git rev-parse --abbrev-ref HEAD)
last_commit=$(git log --pretty=format:"%H" -1)
last_tag=""
spec_file=""

#Checking if used branch is correct
if [ "$current_branch" = "master" ]; then
    last_tag=$(git tag -l | sed -e '/beta/d' | tail -1)
    spec_file=$(ls | grep '\.podspec$' | sed -e '/beta/d' | sed -n 1p)
elif [ "$current_branch" = "develop" ]; then
    last_tag=$(git tag -l | sed -e '/beta/!d' | tail -1)
    spec_file=$(ls | grep '\.podspec$' | sed -e '/beta/!d' | sed -n 1p)
else
    echo "${red}${current_branch} does not match to any of release branches! Checkout to master or develop.${endColor}"
    exit 1
fi

#Checking if version in podspec fits to current tag
spec_version=$(grep ".version[^.]" $spec_file | grep -o '".*"' | sed 's/"//g')
tag_version=${last_tag%"-beta"}

if [ "$spec_version" != "$tag_version" ]; then
    echo "${yellow}Version used in ${spec_file} (${spec_version}) does not match to last tag version (${tag_version}).${endColor}"
    printf "${yellow}Do you want to continue? (y/N):${endColor} "
    read -r answer
    should_continue=$(echo $answer | tr '[A-Z]' '[a-z]')
    if [ "$should_continue" != "y" ] && [ "$should_continue" != "yes" ]; then
        echo "${red}Terminating script due to podspec and tag versions mismatch.${endColor}"
        exit 1
    fi
fi

echo "${yellow}Deleting tag ${last_tag}...${endColor}"
#Remove last tag locally
if [ -n "$verbosed" ]; then
    git tag -d $last_tag
else
    git tag -d $last_tag &> /dev/null
fi
#Remove last tag remotely
if [ -n "$verbosed" ]; then
    git push origin :refs/tags/$last_tag
else
    git push origin :refs/tags/$last_tag &> /dev/null
fi

echo "${yellow}Adding tag $last_tag to last commit...${endColor}"
#Add last tag to last commit
if [ -n "$verbosed" ]; then
    git tag -a $last_tag $last_commit -m "Moved tag to newest commit"
else
    git tag -a $last_tag $last_commit -m "Moved tag to newest commit" &> /dev/null
fi
#Push this tag
if [ -n "$verbosed" ]; then
    git push origin $current_branch --follow-tags
else
    git push origin $current_branch --follow-tags &> /dev/null
fi

#Validate pod
echo "${yellow}Validating lib...${endColor}"
validation=$(pod lib lint $spec_file --no-clean --allow-warnings $use_libraries)
if [ -n "$verbosed" ]; then
        echo "$validation"
fi

words=($(echo "$validation" | tail -1))
if [ "${words[1]}" = "passed" ]; then
    echo "${yellow}Pushing pod repo...${endColor}"
    pushing=$(pod repo push $spec_branch_name $spec_file $use_libraries)
    if [ -n "$verbosed" ]; then
        echo "$pushing"
    fi

    words=($(echo "$pushing" | tail -1))
    if [ "${words[0]}" = "error:" ]; then
        echo "${yellow}Pushing ${spec_branch_name} manually...${endColor}"
        start_path=$(pwd)
        cd ~/.cocoapods/repos/$spec_branch_name/
        if [ -n "$verbosed" ]; then
            git push
        else
            git push &> /dev/null
        fi
        cd $start_path
    fi

    if [ -d "Example/" ]; then
        echo "${yellow}Updating pods...${endColor}"
        cd Example/
        if [ -n "$verbosed" ]; then
            pod update
        else
            pod update &> /dev/null
        fi
        cd ../
    fi
else
    echo "${red}${spec_file} did not pass validation!${endColor}"
fi

echo "${green}Finished!${endColor}"
