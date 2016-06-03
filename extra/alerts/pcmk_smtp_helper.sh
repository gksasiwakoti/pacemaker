#!/bin/bash
#
# Copyright (C) 2016 Klaus Wenninger <kwenning@redhat.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public
# License as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later version.
#
# This software is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
##############################################################################
#
# Sample configuration (cib fragment in xml notation)
# ================================
# <configuration>
#   <alerts>
#     <alert id="smtp_alert" path="/path/to/pcmk_smtp_helper.sh">
#       <instance_attributes id="config_for_pcmk_smtp_helper">
#         <nvpair id="cluster_name" name="cluster_name" value=""/>
#         <nvpair id="email_client" name="email_client" value=""/>
#         <nvpair id="email_sender" name="email_sender" value=""/>
#       </instance_attributes>
#       <recipient id="smtp_destination" value="admin@where.admin.lives"/>
#     </alert>
#   </alerts>
# </configuration>

email_client_default="sendmail"
email_sender_default="hacluster"

: ${email_client=${email_client_default}}
: ${email_sender=${email_sender_default}}

node_name=`uname -n`
cluster_name=`crm_attribute --query -n cluster-name -q`
email_body=`env | grep CRM_alert_`

if [ -z ${email_sender##*@*} ]; then
    email_sender="${email_sender}@${node_name}"
fi

if [ -z ${CRM_alert_version} ]; then
    email_subject="Pacemaker version 1.1.15 is required for smtp-helper"

else

    case ${CRM_alert_kind} in
        node)
            email_subject="${CRM_alert_timestamp} ${cluster_name}: Node '${CRM_alert_node}' is now '${CRM_alert_desc}'"
            ;;
        fencing)
            email_subject="${CRM_alert_timestamp} ${cluster_name}: Fencing ${CRM_alert_desc}"
            ;;
        resource)
            if [ ${CRM_alert_interval} = "0" ]; then
                CRM_alert_interval=""
            else
                CRM_alert_interval=" (${CRM_alert_interval})"
            fi

            if [ ${CRM_alert_target_rc} = "0" ]; then
                CRM_alert_target_rc=""
            else
                CRM_alert_target_rc=" (target: ${CRM_alert_target_rc})"
            fi

            case ${CRM_alert_desc} in
                Cancelled) ;;
                *)
                    email_subject="${CRM_alert_timestamp} ${cluster_name}: Resource operation '${CRM_alert_task}${CRM_alert_interval}' for '${CRM_alert_rsc}' on '${CRM_alert_node}': ${CRM_alert_desc}${CRM_alert_target_rc}"
                    ;;
            esac
            ;;
        *)
            email_subject="${CRM_alert_timestamp} ${cluster_name}: Unhandled $CRM_alert_kind alert"
            ;;

    esac

    if [ ! -z ${email_subject} ]; then
        case $email_client in
            sendmail)
                sendmail -F "${email_sender}" "${CRM_alert_recipient}" <<__EOF__
Subject: ${email_subject}

${email_body}
__EOF__
                ;;
            *)
                ;;
        esac
fi
