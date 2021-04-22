# Blocking inactive users in Gitlab

General propose: deactivate, block and delete inactive Gitlab users. 

## Quick Start

- **Create full backup your existing Gitlab installation before run script!**
- Copy script into `/var/opt/gitlab/.rake` (create if it doesn't exist).
- Check variable `excluded_users` and `excluded_by_mask` for excluding some users. Bot's will be excluded automatically.
- Check `log_file_path` for script logging, user must have sufficient privileges.
- Console run: in terminal `gitlab-rake -R /var/opt/gitlab/.rake/ mycompany:block_inactive_users BLOCK=true`
- Cron schediling: `0 0 * * 0 /usr/bin/gitlab-rake -R /var/opt/gitlab/.rake/ mycompany:block_inactive_users BLOCK=true`
- After script complete, check log file for detailed info.

If `BLOCK` flag doesn't exist or not set to `true` script running in `dry-run mode` (i.e. no deletion/blocking/deactivating user accounts).

## Gitlab: users, status, seats

- https://docs.gitlab.com/ee/user/admin_area/activating_deactivating_users.html
- https://docs.gitlab.com/ee/user/admin_area/blocking_unblocking_users.html
- https://docs.gitlab.com/ee/user/profile/account/delete_account.html

## LDAP sync and blocking users

- https://docs.gitlab.com/ee/administration/auth/ldap/#user-sync

## Script steps

- Fill `excluded_users` (users and bots) and `excluded_by_mask`
- Step 1. Delete blocked users without Projects and last activity more than 90 days
- Step 2. Block deactivated users with last activity more than 60 days
- Step 3. Deactivate users with last activity (`last_activity_on`) is `nil` or more than 35 days


## TO-DO

- Send report by E-mail

## Known problems

- Message "WARNING: Active Record does not support composite primary key. Project_authorizations has composite primary key. Composite primary key is ignored". Has no effect for script, fixed in Gitlab 13.9.
