# This script Delete/Block/Deactivate inactive and dismissed users in GitLab
#
# Usage:
# 1. Copy file to directory /var/opt/gitlab/.rake/
# 2. Run
#   console:    gitlab-rake -R /var/opt/gitlab/.rake/ mycompany:block_inactive_users BLOCK=true
#   cron:       0 0 * * 0 /usr/bin/gitlab-rake -R /var/opt/gitlab/.rake/ mycompany:block_inactive_users BLOCK=true
# Remember: flag BLOCK=true for block users, else script run in 'dry-run' mode
# 3. Check log
#
# - v.0.0.3 - fix log file name (replace ':' to '-')
# - v.0.0.2 - fix log file name (replace ' ' to '_', remove TimeZone)
# - v.0.0.1 - first release

namespace :mycompany do
    desc "MyCompany | Gitlab | Block inactive users"
    task block_inactive_users: :gitlab_environment do
      warn_user_is_not_gitlab
  
      # Global Variables
  
      # Time Periods
      period_delete = 90.days
      period_block = 60.days
      period_deactivate = 35.days
  
      # Excluded users by 'username'
      excluded_users = ['root','Your.Username']
      # Search users by mask 'SELECT username LIKE "excluded_by_mask"
      excluded_by_mask = "%srv%"
  
      # Statistic variables
      stat_deleted = 0
      stat_not_deleted = 0
      stat_blocked = 0
      stat_deactivated = 0
      stat_excluded = 0
  
      # Log settings
      log_file_path = "/var/log/gitlab/block-users"
  
      # End of variables -----
  
      # Get environment flag for making real changes
      block_flag = ENV['BLOCK']
  
      # Start time, for example: "2021-05-19 19:10:01 +0300"
      time_start = Time.now
  
      # Create log dir if doesn't exist
      log_file_name = "block-users-#{time_start}"
      log_file_name = ((log_file_name.split(' +')[0]).gsub! ' ','_').gsub! ':','-' # Remove TimeZone, Replace ' ' to '_' and ':' to '-'
      log_file = File.open("#{log_file_path}/#{log_file_name}.log", "w")
      log_file.write "Task started at: #{time_start}\n"
  
      # Search administrative username for auditing purposes
      current_user = User.find_by(username: 'root')
  
      # Search for bots and add to exclude list
      for bot in User.bots do
          excluded_users.push bot.username
      end
  
      # Search If excluded_by_mask is not empty
      if excluded_by_mask.length > 0
          then
              for user in User.where("username like \'#{excluded_by_mask}\'") do
                  excluded_users.push user.username
              end
      end
  
      # Step 1. Search users older than period_delete days for Delete
      users = User.blocked.where("current_sign_in_at <= ? AND (last_activity_on <= ? OR last_activity_on IS ?)", period_delete.ago, period_delete.ago, nil)
  
      if users.count > 0
          log_file.write "\n-----[DELETE USERS TASK]-----\n"
          users.each do |user|
              log_file.write "  User: #{user.username} / current_sign_in_at: #{user.current_sign_in_at} / last_activity_on: #{user.last_activity_on} ..."
              
              # Check for excluded acounts and bots 
              if not excluded_users.include? "#{user.username}"
                then # User not in exclude list

                    if block_flag # Check blocking flag, if true we can delete user

                        # Search for users Projects
                        if ProjectAuthorization.find_by(user_id: user.id) != nil
                            then
                                stat_not_deleted += 1
                                log_file.write " [Not Deleted (have a Projects)]\n"
                            else
                                
                                # DELETE ACTION
                                DeleteUserWorker.perform_async(current_user.id, user.id)

                                stat_deleted += 1
                                log_file.write " [DELETED]\n"
                        end
                    else
                        log_file.write " [May be Deleted]\n"
                end        
              else
                # User in exclude list
                stat_excluded += 1
                log_file.write " [EXCLUDED]\n"
              end
          end
          log_file.write "Total for deletion #{users.count} | Deleted: #{stat_deleted} | Not deleted: #{stat_not_deleted} | Excluded: #{stat_excluded}\n"
      else
          log_file.write "\n[DELETE USERS TASK]: No user for deletion\n"
      end
  
      # Step 2. Search users older than period_block days for Block
      users = User.deactivated.where("current_sign_in_at <= ? AND (last_activity_on <= ? OR last_activity_on IS ?)", period_block.ago, period_block.ago, nil)
  
      if users.count > 0
          log_file.write "\n-----[BLOCK USERS TASK]-----\n"
          users.each do |user|
              log_file.write "  User: #{user.username} / current_sign_in_at: #{user.current_sign_in_at} / last_activity_on: #{user.last_activity_on} ..."
              
              # Check for excluded acounts and bots 
              if not excluded_users.include? "#{user.username}"
                  then # User not in exclude list
  
                      if block_flag
                          user.block! unless user.blocked?
                          stat_blocked += 1
                          log_file.write " [BLOCKED]\n"
                      else
                          log_file.write " [Must be Blocked]\n"
                      end
                  else
                      stat_excluded += 1
                      log_file.write " [EXCLUDED]\n"
                  end
          end
          log_file.write "Total blocked users: #{users.count}\n"
      else
          log_file.write "\n[BLOCK USERS TASK]: No User for blocking\n"
      end
  
      # Step 3. Search users older than period_deactivate days for Deactivate
      users = User.active.where("current_sign_in_at <= ? AND (last_activity_on <= ? OR last_activity_on IS ?)", period_deactivate.ago, period_deactivate.ago, nil)
  
      if users.count > 0
          log_file.write "\n-----[DEACTIVATE USERS TASK]-----\n"
          users.each do |user|
              log_file.write "  User: #{user.username} / current_sign_in_at: #{user.current_sign_in_at} / last_activity_on: #{user.last_activity_on} ..."
              
              # Check for excluded acounts and bots 
              if not excluded_users.include? "#{user.username}"
                  then # User not in exclude list
  
                      if block_flag
                          user.deactivate! unless user.deactivated?
                          stat_deactivated += 1
                          log_file.write " [DEACTIVATED]\n"
                      else
                          log_file.write " [Must be Deactivated]\n"
                      end
                  else
                      stat_excluded += 1
                      log_file.write " [EXCLUDED]\n"
                  end    
          end
          log_file.write "Total deactivated users: #{users.count}\n"
      else
          log_file.write "\n[DEACTIVATE USERS TASK]: No User for deactivating\n"
      end
  
      # Show statistics
      log_file.write "\nScript statistics:\n"
      log_file.write " - Deleted users: #{stat_deleted}\n"
      log_file.write " - Not deleted: #{stat_not_deleted}\n"
      log_file.write " - Blocked users: #{stat_blocked}\n"
      log_file.write " - Deactivated users: #{stat_deactivated}\n"
      log_file.write " - Excluded users in work: #{stat_excluded}\n"
      log_file.write "\nList of Excluded users: #{excluded_users.inspect} / Total: #{excluded_users.count}\n"
  
      log_file.write "\nGitlab Overall Statistics:\n"
      log_file.write " - Active users: #{User.active.count}\n"
      log_file.write " - Deactivated users: #{User.deactivated.count}\n"
      log_file.write " - Blocked users: #{User.blocked.count}\n"    
  
      time_stop = Time.now
      log_file.write "\nTask start at: #{time_start.inspect}\n"
      log_file.write "Task stop at: #{time_stop.inspect}\n"
  
      unless block_flag
          log_file.write "\nRunning in dry-mode. To block a users run this command with BLOCK=true\n"
      end
  
      # Close log file
      log_file.close
  
    end
  end
  
