#!/bin/bash

COMMAND=$1

function transcoding_debug_output {
	echo "$*"
}

function transcoding_error_and_exit {
	echo "$*" >&2
	exit 1
}

function transcoding_set_profile_property {
	FILEPATH=$1
	KEY=$2
	VALUE=$3
	JQ_COMMAND="jq"
	if [ -f "vendor/jq" ]
	then
		JQ_COMMAND=vendor/jq
	fi

	TMP_FILEPATH="${FILEPATH}.part"
	cat $FILEPATH | $JQ_COMMAND .$KEY=\"$VALUE\" > $TMP_FILEPATH && mv $TMP_FILEPATH $FILEPATH
}

function transcoding_check_dependencies {
	if [ -z `which uuidgen` ]
	then
		transcoding_error_and_exit "error: please install uuidgen to use transcoding.sh"
	fi
	if [ -z `which grep` ]
	then
		transcoding_error_and_exit "error: please install grep to use transcoding.sh"
	fi
	if [ -z `which rev` ]
	then
		transcoding_error_and_exit "error: please install rev to use transcoding.sh"
	fi
	if [ -z `which cut` ]
	then
		transcoding_error_and_exit "error: please install cut to use transcoding.sh"
	fi
	if [ -z `which ls` ]
	then
		transcoding_error_and_exit "error: please install ls to use transcoding.sh"
	fi
	if [ -z `which tr` ]
	then
		transcoding_error_and_exit "error: please install tr to use transcoding.sh"
	fi
	if [ -z `which jq` ]
	then
		if [ ! -f "vendor/jq" ]
		then
			transcoding_error_and_exit "error: please install jq from http://stedolan.github.io/jq/download/ or put it into vendor/jq"
		fi
	fi
}

function transcoding_pid_by_workerid {
	WORKER_ID=$1
	WORKER_HOSTNAME=`hostname`

	if [ ! -f  workers/$WORKER_HOSTNAME/$WORKER_ID.pid ]
	then
		transcoding_error_and_exit "error: cannot find pid file for workerid $WORKER_ID"
	fi

	WORKER_PID=`cat workers/$WORKER_HOSTNAME/$WORKER_ID.pid`
	echo $WORKER_PID
}

function transcoding_cleanup_target_directory_for_worker {
	WORKER_ID=$1

	WORKER_LOCATION_FILE=workers/$WORKER_HOSTNAME/$WORKER_ID.location
	TARGET_DIRECTORY=`cat $WORKER_LOCATION_FILE`

	if [ -z "$TARGET_DIRECTORY" ]
	then
		transcoding_error_and_exit "error: the target directory of a worker can not be empty!"
	fi

	find $TARGET_DIRECTORY -mindepth 1 -exec rm -rf {} \;
}

function transcoding_cleanup_worker {
	WORKER_ID=$1

	WORKER_HOSTNAME=`hostname`
	WORKER_PID_FILE=workers/$WORKER_HOSTNAME/$WORKER_ID.pid
	WORKER_LOCATION_FILE=workers/$WORKER_HOSTNAME/$WORKER_ID.location
	WORKER_LOG_FILE=workers/$WORKER_HOSTNAME/$WORKER_ID.log

	if [ -f $WORKER_PID_FILE ]
	then
		rm $WORKER_PID_FILE
	fi

	if [ -f $WORKER_LOCATION_FILE ]
	then
		rm $WORKER_LOCATION_FILE
	fi

	if [ -f $WORKER_LOG_FILE ]
	then
		rm $WORKER_LOG_FILE
	fi

	return 0
}

function transcoding_handle_ffmpeg_exit_code {
	WORKER_ID=$1
	FFMPEG_EXIT_CODE=$2

	if [ ! "$FFMPEG_EXIT_CODE" == "0" ]
	then
		transcoding_cleanup_target_directory_for_worker $WORKER_ID
		echo "Ffmpeg did not finish properly (code: $FFMPEG_EXIT_CODE)!" >&2
	fi

	transcoding_cleanup_worker $WORKER_ID

	exit $FFMPEG_EXIT_CODE
}

function transcoding_start_worker {
	MAX_WORKER_COUNT=$1
    WORKER_ID=`uuidgen`
	WORKER_HOSTNAME=`hostname`
	if [ ! -d "workers/$WORKER_HOSTNAME" ]
	then
		mkdir -p "workers/$WORKER_HOSTNAME"
	fi

	if [ ! -z "$MAX_WORKER_COUNT" ]
	then
		WORKERS_COUNT=`ls workers/$WORKER_HOSTNAME | grep '.pid\$' | wc -l | tr -d ' '`

		if [ ! "$MAX_WORKER_COUNT" -gt "$WORKERS_COUNT" ]
		then
			transcoding_debug_output "already $WORKERS_COUNT/$MAX_WORKER_COUNT workers running. won't start a new one!"
			return 0
		fi
	fi

    find assets -type d -empty | while read TARGET_DIRECTORY
    do
        transcoding_debug_output "target directory: $TARGET_DIRECTORY"
        PROFILE_NAME=`basename $TARGET_DIRECTORY`
        SOURCE_DIRECTORY=`dirname $TARGET_DIRECTORY`/source
        PROFILE_ENV_FILEPATH=`dirname $TARGET_DIRECTORY`/$PROFILE_NAME.env
        SOURCE_FILENAME=`ls $SOURCE_DIRECTORY | head -n 1`
        SOURCE_FILEPATH=$SOURCE_DIRECTORY/$SOURCE_FILENAME
        STATUS_FILEPATH=$TARGET_DIRECTORY/status.json

        WORKER_PID_FILE=workers/$WORKER_HOSTNAME/$WORKER_ID.pid
        WORKER_LOCATION_FILE=workers/$WORKER_HOSTNAME/$WORKER_ID.location
        WORKER_LOG_FILE=workers/$WORKER_HOSTNAME/$WORKER_ID.log

        transcoding_debug_output "worker pid file: $WORKER_PID_FILE"
        transcoding_debug_output "profile name: $PROFILE_NAME"
        transcoding_debug_output "source directory: $SOURCE_DIRECTORY"
        transcoding_debug_output "source filename: $SOURCE_FILENAME"
        transcoding_debug_output "source filepath: $SOURCE_FILEPATH"
        transcoding_debug_output "status filepath: $STATUS_FILEPATH"
        if [ ! -f "profiles/$PROFILE_NAME" ]
        then
            transcoding_debug_output "error: cannot find profile $PROFILE_NAME in folder profiles"
        else
			echo -n "$TARGET_DIRECTORY" > $WORKER_LOCATION_FILE
			echo -n "" > $WORKER_PID_FILE
			echo '{"state": "initializing"}' > $STATUS_FILEPATH
			transcoding_set_profile_property $STATUS_FILEPATH "state" "running"

			trap "{ transcoding_handle_ffmpeg_exit_code $WORKER_ID 255; exit $? }" SIGINT SIGTERM

			if [ -f "$PROFILE_ENV_FILEPATH" ]
			then
				source $PROFILE_ENV_FILEPATH
			fi
            source "profiles/$PROFILE_NAME"
			FFMPEG_PID=$!
			echo -n "$FFMPEG_PID" > $WORKER_PID_FILE
			echo "Launched ffmpeg with pid: $FFMPEG_PID"
			echo "Waiting for ffmpeg to finish ..."
			wait $FFMPEG_PID
			FFMPEG_EXIT_CODE=$?

			if [ "$FFMPEG_EXIT_CODE" == "0" ]
			then
				transcoding_set_profile_property $STATUS_FILEPATH "state" "finished"
				echo "Ffmpeg finished with exit code $FFMPEG_EXIT_CODE!"
			fi

			transcoding_handle_ffmpeg_exit_code $WORKER_ID $FFMPEG_EXIT_CODE
        fi
    done

    transcoding_debug_output "done"
}

function transcoding_worker_status {
	WORKER_IDS=$1

	if [ -z "$WORKER_IDS" ]
	then
		WORKER_IDS=`transcoding_list_workers`
	fi

	for WORKER_ID in $WORKER_IDS
	do
		WORKER_PID=`transcoding_pid_by_workerid $WORKER_ID`
		WORKER_SYSTEM_STATS=`UNIX95=;LANG=en_US.UTF8 ps -p $WORKER_PID -o pid,%cpu,%mem,etime,lstart | tail -n 1 | tr -s ' '`
		WORKER_CPU=`echo "$WORKER_SYSTEM_STATS" | cut -f '2' -d ' '`
		WORKER_MEM=`echo "$WORKER_SYSTEM_STATS" | cut -f '3' -d ' '`
		WORKER_TIME=`echo "$WORKER_SYSTEM_STATS" | cut -f '4' -d ' '`
		WORKER_START_TIME=`echo "$WORKER_SYSTEM_STATS" | cut -f '5-8' -d ' '`
		echo "worker cpu: $WORKER_CPU"
		echo "worker mem: $WORKER_MEM"
		echo "worker time: $WORKER_TIME"
		echo "worker start time: $WORKER_START_TIME"
	done
}

function transcoding_stop_worker {
	WORKER_ID=$1
	WORKER_PID=`transcoding_pid_by_workerid $WORKER_ID`

	kill -2 $WORKER_PID
	return 0
}

function transcoding_list_workers {
	WORKER_HOSTNAME=`hostname`

	if [ -d "workers/$WORKER_HOSTNAME" ]
	then
		ls workers/$WORKER_HOSTNAME | grep .pid | rev | cut -f '1' -d '/' | cut -f '2' -d '.' | rev | while read WORKER_ID
		do
			echo "$WORKER_ID"
		done
	fi

	return 0
}

function transcoding_stop_workers {
	WORKER_HOSTNAME=`hostname`

	if [ -d "workers/$WORKER_HOSTNAME" ]
	then
		ls workers/$WORKER_HOSTNAME | grep .pid | rev | cut -f '1' -d '/' | cut -f '2' -d '.' | rev | while read WORKER_ID
		do
			transcoding_stop_worker $WORKER_ID
		done
	fi

	return 0
}

function transcoding_cleanup_workers {
	CLEANUP_MODE=$1
	WORKER_HOSTNAME=`hostname`

	if [ -d "workers/$WORKER_HOSTNAME" ]
	then
		ls workers/$WORKER_HOSTNAME | grep .pid | rev | cut -f '1' -d '/' | cut -f '2' -d '.' | rev | while read WORKER_ID
		do
			WORKER_PID=`transcoding_pid_by_workerid $WORKER_ID`

			kill -0 $WORKER_PID 2>/dev/null
			PID_CHECK_CODE=$?
			if [ "$PID_CHECK_CODE" == "0" ]
			then
				echo "$WORKER_ID: alive ($WORKER_PID)"
			else
				if [ "$CLEANUP_MODE" == "cleanup" ]
				then
					echo "$WORKER_ID: dead (removing the .pid/.location file)"
					transcoding_cleanup_worker $WORKER_ID
				else
					echo "$WORKER_ID: dead"
				fi
			fi
		done
	fi

	return 0
}

transcoding_check_dependencies

case "$COMMAND" in
    "list-workers")
        transcoding_list_workers
        exit $?
        ;;
    "check-workers")
        transcoding_cleanup_workers "check"
        exit $?
        ;;
    "cleanup-workers")
        transcoding_cleanup_workers "cleanup"
        exit $?
        ;;
    "stop-worker")
        transcoding_stop_worker $2
        exit $?
        ;;
    "worker-status")
    	transcoding_worker_status $2
        exit $?
        ;;
	"stop-workers")
		transcoding_stop_workers
		exit $?
		;;
    "start-worker")
        transcoding_start_worker $2
        exit $?
        ;;
esac

transcoding_error_and_exit "Unsupported COMMAND: $COMMAND" >&2
