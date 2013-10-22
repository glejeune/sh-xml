#!/bin/sh
# Copyright 2012 Grégoire Lejeune. All Rights Reserved.
# Released under the LGPL (GNU Lesser General Public License)
#
# sh-xml -- a (very) naive XML parser for sh
#
# Author: gregoire.lejeune@free.fr (Grégoire Lejeune)

# Using sed to set passwords with arguments on the command line makes
# it possible to see the new passwords using ps. This function creates
# a temp file which is used as a script for sed (using the -f option).
# This is safe because what's put in the file is done with echo, which
# is a built-in shell command, so it will not appear in /proc.
# Params:
#    $1 Sed script to replace values in a config file
#    $2 data to change
safesed () {
  SAFESED_SCRIPT="${1}"
  SAFESED_DATA="${2}"

  SAFESED_SCRIPT_TMPFILE=`mktemp -t safe_sed_script.XXXXXX`
  SAFESED_DATA_TMPFILE=`mktemp -t safe_sed_data.XXXXXX`
  echo "${SAFESED_SCRIPT}" > ${SAFESED_SCRIPT_TMPFILE}
  echo "${SAFESED_DATA}" > ${SAFESED_DATA_TMPFILE}

  NEW_CONTENT=$(sed -f ${SAFESED_SCRIPT_TMPFILE} ${SAFESED_DATA_TMPFILE})

  rm -f ${SAFESED_SCRIPT_TMPFILE}
  rm -f ${SAFESED_DATA_TMPFILE}

  echo "${NEW_CONTENT}"
}

# This fontion is called once for each file. It initialize the parser
#
# Type: private
# Parameters:
#  * 1: path of the XML file
# Return: nothing
_init_xml() {
  local XML_FILE=${1}
  _TEMP_XML_FILE=$(mktemp)
  _XML_CONTINUE_READING=true
  cat $XML_FILE > $_TEMP_XML_FILE
  XML_PATH=""
  unset XML_ENTITY 
  unset XML_CONTENT
  unset XML_TAG_TYPE 
  unset XML_TAG_NAME 
  unset XML_COMMENT
  unset _XML_ATTRIBUTES
  unset _XML_ATTRIBUTES_FOR_PARSING
}

# This fontion is called once for each file. It terminate the parser
#
# Type: private
# Parameters: none
# Return: nothing
_close_xml() {
  [ -f $_TEMP_XML_FILE ] && rm -f $_TEMP_XML_FILE
}

# This fonction read the DOM. It is called for every XML tags found.
# Once this function has been called, the following variables are set :
#  * XML_ENTITY: The current XML entity
#  * XML_CONTENT : Data found after the current XML entity
#  * XML_TAG_NAME : Name of the current tag. If the current tag is a close tag, the heading "/" is present in the tag name
#  * XML_TAG_TYPE : Type of the current tag. The value can be "OPEN", "CLOSE", "EMPTY", "COMMENT" or "INSTRUCTION"
#  * XML_COMMENT : If the current tag is of type "COMMENT", this variable contains the text of the comment
#  * XML_PATH : Full XPath path of the current tag
#
# Type: private
# Parameters: none
# Return: nothing
_read_dom() {
  local XML_DATA 
  local XML_TAG_NAME_FIRST_CHAR 
  local XML_TAG_NAME_LENGTH 
  local XML_TAG_NAME_WITHOUT_FIRST_CHAR
  local XML_LAST_CHAR_OF_ATTRIBUTES

  # If the last tag read was of type "EMPTY", we update the XPath path 
  # before searching the next tag
  if [ "$XML_TAG_TYPE" = "EMPTY" ]; then
    XML_PATH=$(echo $XML_PATH | sed -e "s/\/$XML_TAG_NAME$//")
  fi

  # Read the XML file to find the next tag
  # The output is a string containing the XML entity and the following 
  # content, seperate by a ">"
  local _TEMP_TEMP_XML_FILE=$(mktemp)
  XML_DATA=$(awk 'BEGIN { RS = "<" ; FS = ">" ; OFS=">"; }
  { printf "" > F }
  NR == 1 { getline ; print $1,$2"x" }
  NR > 2 { printf "<"$0 >> F }' F=${_TEMP_TEMP_XML_FILE} ${_TEMP_XML_FILE})
  cat $_TEMP_TEMP_XML_FILE > $_TEMP_XML_FILE
  rm -f $_TEMP_TEMP_XML_FILE
  if [ ! -s ${_TEMP_XML_FILE} ]; then
    _XML_CONTINUE_READING=false
  fi

  XML_ENTITY=$(echo $XML_DATA | cut -d\> -f1)
  XML_CONTENT=$(printf "$XML_DATA" | cut -d\> -f2-)
  XML_CONTENT=${XML_CONTENT%x}

  unset XML_COMMENT
  unset _XML_ATTRIBUTES
  unset _XML_ATTRIBUTES_FOR_PARSING
  XML_TAG_TYPE="UNKNOW"
  XML_TAG_NAME=${XML_ENTITY%% *}
  _XML_ATTRIBUTES=${XML_ENTITY#* }


  # Determines the type of tag, according to the first or last character of the XML entity
  XML_TAG_NAME_FIRST_CHAR=$(echo $XML_TAG_NAME | awk  '{ string=substr($0, 1, 1); print string; }' )
  XML_TAG_NAME_LENGTH=${#XML_TAG_NAME}
  XML_TAG_NAME_WITHOUT_FIRST_CHAR=$(echo $XML_TAG_NAME | awk -v var=$XML_TAG_NAME_LENGTH '{ string=substr($0, 2, var - 1); print string; }' )
  # The first character is a "!", the tag is a comment
  if [ $XML_TAG_NAME_FIRST_CHAR = "!" ] ; then
    XML_TAG_TYPE="COMMENT"
    unset _XML_ATTRIBUTES
    unset XML_TAG_NAME
    XML_COMMENT=$(echo "$XML_ENTITY" | sed -e 's/!-- \(.*\) --/\1/')
  else
    [ "$_XML_ATTRIBUTES" = "$XML_TAG_NAME" ] && unset _XML_ATTRIBUTES

    # The first character is a "/", the tag is a close tag
    if [ "$XML_TAG_NAME_FIRST_CHAR" = "/" ]; then
      XML_PATH=$(echo $XML_PATH | sed -e "s/\/$XML_TAG_NAME_WITHOUT_FIRST_CHAR$//")
      XML_TAG_TYPE="CLOSE"
    # The first character is a "?", the tag is an instruction tag
    elif [ "$XML_TAG_NAME_FIRST_CHAR" = "?" ]; then
      XML_TAG_TYPE="INSTRUCTION"
      XML_TAG_NAME=$XML_TAG_NAME_WITHOUT_FIRST_CHAR
    # The tag is an open tag
    else
      XML_PATH=$XML_PATH"/"$XML_TAG_NAME
      XML_TAG_TYPE="OPEN"
    fi

    # If the last character of the XML entity is a "/" the tag is en "openclose" tag
    XML_LAST_CHAR_OF_ATTRIBUTES=$(echo "$_XML_ATTRIBUTES"|awk '$0=$NF' FS=)
    if [ "$_XML_ATTRIBUTES" != "" ] && [ "${XML_LAST_CHAR_OF_ATTRIBUTES}" = "/" ]; then
      _XML_ATTRIBUTES=${_XML_ATTRIBUTES%%?}
      XML_TAG_TYPE="EMPTY"
    fi
  fi

  if [ "$_XML_ATTRIBUTES" != "" ] ; then
    _XML_ATTRIBUTES_FOR_PARSING=$(safesed "s|[[:space:]]*=[[:space:]]*|=|g" "${_XML_ATTRIBUTES}")
  fi
}

# This fontion is the main parser
# Parameters:
#  * 1: a string containing the name of function called for each tag found
#  * 2: path of the XML file
# Type: public
# Return: nothing
# Remarque: In the function given in first argument, you have acces to the 
# whole variables set in the private function _read_dom.
# Example :
# 
#     do_xml() {
#        echo $XML_PATH
#     }
#     parse_xml "do_xml" /path/to/sample.xml
parse_xml() {
  local XML_FUNCTION=$1
  local XML_FILE=$2

  _init_xml ${XML_FILE}

  while ${_XML_CONTINUE_READING}; do
    _read_dom
    eval ${XML_FUNCTION}
  done

  _close_xml
}

# This function allow you to get the value of the attribute which name is passed as parameter
# Parameters:
#  * 1: name of the attribut
# Type: public
# Return: the value of the attribute
# Example :
# 
#     VALUE=$(get_attribute_value "name")
get_attribute_value() {
  ATTRIBUT_NAME=$1

  ATTRIBUT_VALUE=$(safesed "/ ${ATTRIBUT_NAME}=\"/s/.* ${ATTRIBUT_NAME}=\"\\([^\"]*\\)\" .*/\\\\1/;/ ${ATTRIBUT_NAME}=/s/.* ${ATTRIBUT_NAME}='\\([^']*\\)' .*/\\\\1/;/ ${ATTRIBUT_NAME}=/s/.* ${ATTRIBUT_NAME}=\\([^ ]*\\) .*/\\\\1/;" " $_XML_ATTRIBUTES_FOR_PARSING ")
  if [ "${ATTRIBUT_VALUE}" = "${_XML_ATTRIBUTES_FOR_PARSING}" ] ; then
    unset ATTRIBUT_VALUE
  fi

  echo "$ATTRIBUT_VALUE"
}

# This function return true of false according to the existance of the 
# attribute which name is passed as parameter
# Parameters:
#  * 1: name of the attribut
# Type: public
# Return: true of false
# Example :
# 
#     has_attribute "name"
#     if [ "$?" = 1 ] ; then
#       echo "attribut name exist"
#     fi
has_attribute() {
  local VALUE="$(get_attribute_value $1)"
  if [ "$VALUE" ] ; then
    return 1
  else
    return 0
  fi
}

# This function allow you to change the value of an attribut
# Parameters:
#  * 1: Name of the attribut
#  * 2: Value of the attribut
# Type: public
# Return: nothing
# Example
# 
#     has_attribute "name"
#     if [ "$?" = 1 ] ; then
#       set_attribute_value "name" "new value for name"
#     fi
set_attribute_value() {
  local ATTRIBUT_NAME=$1
  local ATTRIBUT_VALUE=$2

  local CURRENT_ATTRIBUT_VALUE="$(get_attribute_value $ATTRIBUT_NAME)"

  _XML_ATTRIBUTES=$(safesed "s|${ATTRIBUT_NAME}[[:space:]]*=[[:space:]]*[\\\"' ]${CURRENT_ATTRIBUT_VALUE}[\\\"' ]|${ATTRIBUT_NAME}=\\\"${ATTRIBUT_VALUE}\\\"|" "${_XML_ATTRIBUTES}")
  _XML_ATTRIBUTES_FOR_PARSING=$(safesed "s|[[:space:]]*=[[:space:]]*|=|g" "${_XML_ATTRIBUTES}")
}

# This function allow you to print the current XML entity to stdout
# Parameters: none
# Type: public
# Return: nothing
# Example
# 
#     print_xml() {
#        print_entity
#     }
#     parse_xml "print_xml" /path/to/sample.xml
print_entity() {
  if [ "$XML_TAG_TYPE" = "COMMENT" ] ; then
    printf "<!-- %s --" "$XML_COMMENT"
  elif [ "$XML_TAG_TYPE" = "INSTRUCTION" ] ; then
    printf "<?%s" "$XML_TAG_NAME"
    if [ "$_XML_ATTRIBUTES" != "" ] ; then
      printf " %s" "$_XML_ATTRIBUTES"
    fi
  elif [ "$XML_TAG_TYPE" = "EMPTY" ] ; then
    printf "<%s" "$XML_TAG_NAME"
    if [ "$_XML_ATTRIBUTES" != "" ] ; then
      printf " %s" "$_XML_ATTRIBUTES"
    fi
    printf "/"
  elif [ "$XML_TAG_TYPE" = "CLOSE" ] ; then
    printf "<%s" "$XML_TAG_NAME"
  else
    printf "<%s" "$XML_TAG_NAME"
    if [ "$_XML_ATTRIBUTES" != "" ] ; then
      printf " %s" "$_XML_ATTRIBUTES"
    fi
  fi
  printf ">$XML_CONTENT"
}

# Terminate parsing. The end of the XML file will not be read.
terminate_parser() {
  _XML_CONTINUE_READING=false
}
