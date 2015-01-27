#!/bin/bash
########## sqldump.sh ##########################################################
#
# Author: Daniel Huckson					Filename: sqldump.sh
#
# Version 0.0.1							Date: 2012/03/28
#
# Purpose:
#		Export and archive MySQL database.
#
################################################################################
#
purge() {
	retval=0
	saved_pwd=`pwd`

	[ "$1" == "" ] && retval=1 || {
		[ "$2" == "" ] && retval=2 || {
			[ ! `expr $2 + 1 2> /dev/null` ] && retval=3 || { 
				[ ! -d "$1" ] && retval=4 || {
					i=0;
					cd $1
					for f in `ls -r *`; do
						[ -f "$f" ] && {
							i=$(( i + 1 ))
							[[ $i -gt `expr $2` ]] && {
								rm -f $f
								[ $? != '0' ] && {
									retval=5
									break	
								}
							}
						}
					done
				}
			}
		}
	}

	[[ $retval -ne 0 ]] && {
		case "$retval" in
			1) echo "Error:$retval, Directory name must not be null." ;;
			2) echo "Error:$retval, You need to indicate the number of files to keep." ;;
			3) echo "Error:$retval, You must supply an interger value." ;;
			4) echo "Error:$retval, Could not locate directory \"$1\"." ;;
			5) echo "Error:$retval, Could not remove file \"$f\"." ;;
			*) echo "Error:$retval, Unknown error type." ;;
		esac
	}	

	cd $saved_pwd
	return $retval
}

start_time=$(date +%s)

index=0
options=$@
arguments=($options)

for argument in $options; do
	index=`expr $index + 1`
	case $argument in
		-u) user="${arguments[index]}" ;;
		-p) password="${arguments[index]}" ;;
		-d) database="${arguments[index]}" ;;
		-f) filename="${arguments[index]}" ;;
		-h) host="${arguments[index]}" ;;
		-r) root="${arguments[index]}" ;; 
		-m) max_archive_files="${arguments[index]}" ;;
	esac
done

retval=0
pwd=`pwd`
filename=$filename"_`date +%s`"

[ ! -d "$root/mysql-backup/$database" ] && {
	mkdir -p "$root/mysql-backup/$database/"{current,archive}
	[[ $? -ne 0 ]] && retval=1
}
[[ $retval -eq 0 ]] && {
	echo;date
	echo "Starting backup process for database ($database)."
	cd "$root/mysql-backup/$database/"
	echo -n "Exporting database \"$database\"."
	mysqldump -q -h $host -u $user --password=$password $database  > $filename.sql
	[[ $? -ne 0 ]] && retval=2 || {
		echo "..(Success!) File size: `stat --printf='%s' $filename.sql | sed -r ':L;s=\b([0-9]+)([0-9]{3})\b=\1,\2=g;t L'` Bytes"
		[ "$(ls -A current)" ] && current_backup=`ls -r current/*_sql.tar.bz2 | tail -n 1`
		echo -n "Compressing exported database file."
		tar -cpjf current/$filename\_sql.tar.bz2 $filename.sql
		[[ $? -ne 0 ]] && retval=3 || {
			echo "..(Success!), File size: `stat --printf='%s' current/$filename\_sql.tar.bz2 | sed -r ':L;s=\b([0-9]+)([0-9]{3})\b=\1,\2=g;t L'` Bytes"
			chmod 600 current/$filename\_sql.tar.bz2	
			echo -n "Removing temporary uncompressed export file."
			rm -f $filename.sql
			[[ $? -ne 0 ]] && retval=4 || {
				echo "..(Success!)"
				[[ `ls current | wc -l` -gt 1 ]] && {
					[ "$current_backup" != "" ] && {
						echo -n "Archiving previously exported file."
						mv $current_backup archive/
						[[ $? -ne 0 ]] && retval=5 || {
							echo "..(Success!)"
							echo -n "Cleaning up, removing old archive files."
							purge archive $max_archive_files
							[[ $? -ne 0 ]] && retval=6 || {
								echo "..(Success!)"
							}
						}
					}
				}
			}
		}
	}
}

case "$retval" in
	0) 
		echo;echo "Backup finished successfully.";
		s=$[$(date +%s) - $start_time]; h=$[$s / 3600]; s=$[$s - $[$h * 3600]]; m=$[$s / 60]; s=$[$s - $[m * 60]]
		[ "$h" != '0' ] && hours=" $h hours" || hours=""
		[ "$m" != '0' ] && minutes=" $m minutes and" || minutes=""
		echo "Backup time$hours$minutes $s seconds."
		echo "----------------------------------------------------------------------"
		;;
	1) echo "..(Failed!)";echo "Error:$retval, Could not create directory \"$root/mysql-backup\"." ;;
	2) echo "..(Failed!)";echo "Error:$retval, Could not export database \"$database\"." ;;
	3) echo "..(Failed!)";echo "Error:$retval, Could not compress database export file." ;;
	4) echo "..(Failed!)";echo "Error:$retval, Could not remove file \"$filename\"." ;;
	5) echo "..(Failed!)";echo "Error:$retval, Could not move old archive file, `pwd`$current_backup to directory `pwd`/archive" ;;
esac

cd "$pwd"

echo $retval > .results.log
#