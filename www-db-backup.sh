#!/bin/bash

# Be careful with filenames i.e. don't change them once they're set.

config_file=$HOME/.www-db-backup.conf

function usage {
    printf "%s\n" "To use:"
    printf "%s  %s\n" "Setup:" "$0 setup /path/to/private.key"
    printf "%s  %s\n" "Encrypt a file:" "$0 encrypt key.pub.pem filename"
    printf "%s  %s\n" "Decrypt a file:" "$0 encrypt key.pem filename"
}

function get_real_path {
    if [ -z $1 ]; then
        echo "Usage $0 setup private_key"
        return 1
    fi

    echo "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
}

function create_conf_file {
    # Currently, this assumes that the base configuration 
    # file is in the same directory as the script

    if [ -f "$config_file" ]; then
        echo "$config_file already exists; I will not overwrite it."
        exit 1
    fi
    
    # Get full path of script
    script_path="${BASH_SOURCE[0]}"

    # If running script from a symlink, resolve it
    while [ -h "$script_path" ]; do
        real_dir="$(cd -P "$(dirname "$script_path")" && pwd)"
        script_path="$(readlink "$script_path")"
        [[ $script_path != /* ]] && script_path="$real_dir/$script_path"
    done

    if [ -z $real_dir ]; then
        real_dir="$(cd -P "$(dirname "$script_path")" && pwd)"
    fi

    if [ -f $real_dir/www-db-backup.conf ]; then
        cp $real_dir/www-db-backup.conf $config_file
    else
        echo "Error: $real_dir/www-db-backup.conf does not exist."
        exit 1
    fi
}

function make_pem_files {
    if [ -z $1 ]; then
        echo "Error: no private key specified."
        return 1
    fi

    local private_key=`get_real_path $1`

    if [ ! -f $private_key ]; then
        echo "Error: $private_key does not exist"
        return 1
    fi

    if [ -f "${private_key}.pem" ]; then
        echo "${private_key}.pem already exists; I will not overwrite it."
    else
        openssl rsa -in $private_key -outform pem > ${private_key}.pem
    fi

    if [ -f "${private_key}.pub.pem" ]; then
        echo "${private_key}.pub.pem already exists; I will not overwrite it."
    else
        openssl rsa -in $private_key -pubout -outform pem > ${private_key}.pub.pem
    fi

    if [ -f "${private_key}-key.bin" ]; then
        echo "${private_key}-key.bin already exists; I will not overwrite it."
    else
        openssl rand -base64 32 > ${private_key}-key.bin
    fi

    if [ -f ${private_key}.pem ] \
        && [ -f ${private_key}.pub.pem ] \
        && [ -f ${private_key}-key.bin ] \
        ; then
        printf "%s\n" "Files created:"
        printf "%s\n" "${private_key}.pem"
        printf "%s\n" "${private_key}.pub.pem"
        printf "%s\n" "${private_key}-key.bin"
        printf "%s\n\n" "$config_file"
        printf "%s\n" "Change $config_file to match your configuration, then run:"
        printf "\t%s\n" "$0 configure"
        printf "%s\n" "to finish setup."
    fi
}

function setup {
    make_pem_files $1
    create_conf_file 
}


function create_folders {
    local destination=$1
    local project_string=$2
    OLD_IFS=$IFS
    IFS=','
    local project_names=$project_string

    # First, create the main folder
    if [ ! -d $destination ]; then
        mkdir $destination
    fi

    for current_project in $project_names; do
        echo "From create_folders: $current_project"
    done

    # Then set up folders for each project
    for current_project in $project_names; do
        if [ ! -d $destination/$current_project ]; then
            echo "Creating folders for $current_project"
            echo "Creating $destination/$current_project/production"
            mkdir -p $destination/$current_project/production
            echo "Creating $destination/$current_project/development"
            mkdir $destination/$current_project/development
        else
            echo "Folders for $current_project already exist"
        fi
    done
    IFS=$OLD_IFS
}

function configure_remote {
    local destination=$1
    local project_names=$2
    local divider_index=`expr index "$destination" ':'`
    local remote_machine=${destination:0: ${divider_index}-1}
    destination=${destination:${divider_index}}

    ssh $remote_machine "$(typeset -f); create_folders $destination \"$project_names\""
}

function run_config_file {
    if [ ! -z $1 ]; then
        config_file=`get_real_path $1`
    fi

    local line_counter=1
    local config_section
    local project_names
    while read line; do
        # Skip comments and empty lines
        if [[ "$line" =~ ^#.*$ ]] \
            || [ -z "$line" ]\
        ; then
            continue
        fi

        # What section am I on?
        if [[ "$line" =~ ^\[.*\]$ ]]; then
            config_section=${line:1: -1}
            continue
        fi

        if [ "$config_section" == "Destination" ]; then
            local destination=$line
        elif [ "$config_section" == "Project Names" ]; then
            if [ -z $project_names ]; then
                project_names=$line
            else
                project_names="$project_names,$line"
            fi
        fi

        ((line_counter++))
    done < $config_file

    if [[ $destination == *"@"* ]]; then
        configure_remote $destination $project_names
    else
        create_folders $destination $project_names
    fi
}

function encrypt_file {

    local public_pem=$1
    local key_file=$2
    local file_name=$3

    if [ ! -f $public_pem ]; then
        echo "$public_pem does not exist."
        return 1
    fi

    if [ ! -f $key_file ]; then
        echo "$key_file does not exist."
        return 1
    fi

    if [ ! -f $file_name ]; then
        echo "$file_name does not exist."
        return 1
    fi

    if openssl rsautl -encrypt -inkey $public_pem -pubin -in $key_file -out ${key_file}.enc \
        && openssl enc -aes-256-cbc -salt -in $file_name -out ${file_name}.enc -pass file:$key_file; then
        printf "%s\n" "Created ${key_file}.enc ${file_name}.enc."
    else
        echo "Error: could not create ${key_file}.enc ${file_name}.enc."
    fi
}

function get_config_list() {
    if [ -z "$1" ]; then
        echo "No config file specified"
        exit 1
    fi

    if [ -z "$2" ]; then
        echo "No section specified"
        exit 1
    fi

    local config=$1 
    local section=$2
    local found_them=false
    local line_counter=1
    local list_holder=''
    while read line; do
        # Don't need comments and empty lines
        if [ "${line:0:1}" == '#' ] || [ -z "$line" ]; then
            continue
        fi

        # Get the lines from the right category
        if [ $found_them == true ] && [ "${line:0:1}" != '[' ]; then
            list_holder="$list_holder $line"
        elif [ "$line" == "$section" ]; then
            found_them=true
        else
            continue
        fi
        ((line_counter++))
    done < $config
    echo $list_holder
}

# In development
function sync_backups {
    if [ -z $1 ]; then
        echo "Error: first argument must be file_name.enc"
        return 1
    fi

    dest=`get_config_list $HOME/.www-db-backup.conf "[Destination]"`
    backup_root=`get_config_list $HOME/.www-db-backup.conf "[Root Folder]"`

    # TODO: send the encrypted file to Gerhard
    #rsync -a \
    #    --progress \

}

#function get_project_name() {
#    folders=`get_config_list $HOME/.www-db-backup.conf "[Project Names]"`
#}

function backup_and_store {
    if [ -z $1 ]; then
        echo "Error: first argument must be file_name.pub.pem"
        return 1
    fi

    #if [ -z $2 ]; then
    #    echo "Error: no file specified."
    #    return 1
    #fi

    local public_pem=`get_real_path $1`
    #local key_file=`get_real_path ${public_pem:0: -8}`
    #local file_name=`get_real_path $2`

    # TODO: get stuff like this into an object that is initialized when
    # the script is run
    backup_root=`get_config_list $HOME/.www-db-backup.conf "[Root Folder]"`

    # Get project name
    OLD_IFS=$IFS
    IFS='/'
    split_path=$public_pem
    for dir in $split_path; do
        echo $dir
    done
    IFS=$OLD_IFS

    #if encrypt_file $public_pem $key_file $file_name; then
    #    mv ${file_name}.enc $backup_root
    #    sync_backups 
    #fi
}

function decrypt_file {
    if [ -z $1 ]; then
        echo "Error: first argument must be file_name.pem"
        return 1
    fi

    if [ -z $2 ]; then
        echo "Error: no file specified."
        return 1
    fi

    local pem=`get_real_path $1`
    local file_name=`get_real_path $2`

    if [ ! -f $pem]; then
        echo "$pem does not exist"
        return 1
    fi

    if [ ! -f $file_name ]; then
        echo "$file_name does not exist"
        return 1
    fi

    openssl rsautl -decrypt -inkey $pem -in $file_name -out ${file_name:0: -4}
}

case "$1" in
    setup)
        setup $2
        ;;
    config)
        run_config_file $2
        ;;
    encrypt)
        backup_and_store $2 $3
        ;;
    decrypt)
        decrypt_file $2 $3
        ;;
    test)
        # run_config_file $2
        # sync_backups
        backup_and_store $2
        ;;
    *)
        usage
esac

exit 0
