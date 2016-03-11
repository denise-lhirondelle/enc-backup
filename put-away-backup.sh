#!/bin/bash

# Be careful with filenames i.e. don't change them once they're set.

function usage {
    printf "%s\n" "To use:"
    printf "%s  %s\n" "Set up pem files:" "$0 setup your_private_key"
    printf "%s  %s\n" "Encrypt a file:" "$0 encrypt key.pub.pem filename"
    printf "%s  %s\n" "Decrypt a file:" "$0 encrypt key.pem filename"
}

# There is a more portable way to do this.
# No time right now.
function get_real_path {
    if [ -z $1 ]; then
        echo "Usage $0 setup private_key"
        return 1
    fi

    echo "$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
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

    if [ -f ${private_key}.pem ] || [ -f ${private_key}.pub.pem ]; then
        echo "Files created: ${private_key}.pem and ${private_key}.pub.pem"
    fi
}

function encrypt_file {
    if [ -z $1 ]; then
        echo "Error: first argument must be file_name.pub.pem"
        return 1
    fi

    if [ -z $2 ]; then
        echo "Error: no file specified."
        return 1
    fi

    local public_pem=`get_real_path $1`
    local file_name=`get_real_path $2`

    if [ ! -f $public_pem ]; then
        echo "$public_pem does not exist"
        return 1
    fi

    if [ ! -f $file_name ]; then
        echo "$file_name does not exist"
        return 1
    fi

    if openssl rsautl -encrypt -inkey $public_pem  -pubin -in $file_name -out ${file_name}.enc ; then
        echo "Created ${file_name}.enc"
    fi
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
        make_pem_files $2
        ;;
    encrypt)
        encrypt_file $2 $3
        ;;
    decrypt)
        decrypt_file $2 $3
        ;;
    test)
        get_real_path $2
        ;;
    *)
        usage
esac

exit 0
