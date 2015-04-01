#!/bin/bash

function transcoding_error_and_exit {
	echo "$*" >&2
	exit 1
}

function transcoding_download_binary {
	if [ ! -z "`which wget`" ]
	then
		wget --quiet $1
		if [ "$?" != "0" ]
		then
			transcoding_error_and_exit "error: download of $1 failed"
		fi
	else
		if [ ! -z "`which curl`" ]
		then
			curl -O -sS $1
			if [ "$?" != "0" ]
			then
				transcoding_error_and_exit "error: download of $1 failed"
			fi
		else
			transcoding_error_and_exit "error: Neither wget nor curl is installed. That's why we cannot fetch the file from the server!"
		fi
	fi
}

if [ "`find . -mindepth 1`" != "" ]
then
	transcoding_error_and_exit "error: root folder `pwd` is not empty. Please create a new folder and run transcoding.sh init again!"
fi

if [ -z "`which jq`" ]
then
	echo "Cannot find jq in your path. Do you want to download it from http://stedolan.github.io/jq/download/?"
	select ANSWER in "Yes" "No"
	do
		case $ANSWER in
			Yes )
				ARCHNAME=64
				OSNAME=linux
				if [ "`uname -s`" == "Darwin" ]
				then
					OSNAME="osx"
				fi

				if [ -z "`uname -m | grep 64`" ]
				then
					ARCHNAME=32
				fi
				mkdir vendor
				cd vendor
				transcoding_download_binary http://stedolan.github.io/jq/download/$OSNAME$ARCHNAME/jq
				chmod +x jq
				cd -
				break;;
			No )
				transcoding_error_and_exit "error: transcoding.sh will not work without jq, please download it from http://stedolan.github.io/jq/download/ and make it available in the PATH."
				break;;
		esac
	done
fi

echo "Do you want to setup default profiles (h264-base, etc)?"
select ANSWER in "Yes" "No"
do
	case $ANSWER in
		Yes )
			mkdir profiles
			# iOS h264 profiles from https://trac.ffmpeg.org/wiki/Encode/H.264
			echo '# All devices iOS devices' > "profiles/h264-baseline-3-0"
			echo 'ffmpeg -i $SOURCE_FILEPATH -movflags +faststart -c:v libx264 -profile:v baseline -level 3.0 -strict -2 $TARGET_DIRECTORY/$SOURCE_FILENAME 2>$WORKER_LOG_FILE &' >> "profiles/h264-baseline-3-0"
			echo "ffprobe -i \$SOURCE_FILEPATH -v quiet -print_format json -show_format -print_format json -show_streams | jq '.streams[] | .nb_frames | tonumber' | sort -n | tail -n 1" >> "profiles/h264-baseline-3-0.totalFrames"
			echo "cat \$WORKER_LOG_FILE | tr '\r' ' ' | grep '^frame=' | rev | tr -s ' ' | cut -f '9' -d ' ' | rev" >> "profiles/h264-baseline-3-0.currentFrame"
			echo '# iPhone 3G and later, iPod touch 2nd generation and later' > "profiles/h264-baseline-3-1"
			echo 'ffmpeg -i $SOURCE_FILEPATH -movflags +faststart -c:v libx264 -profile:v baseline -level 3.1 -strict -2 $TARGET_DIRECTORY/$SOURCE_FILENAME 2>$WORKER_LOG_FILE &' >> "profiles/h264-baseline-3-1"
			echo "ffprobe -i \$SOURCE_FILEPATH -v quiet -print_format json -show_format -print_format json -show_streams | jq '.streams[] | .nb_frames | tonumber' | sort -n | tail -n 1" >> "profiles/h264-baseline-3-1.totalFrames"
			echo "cat \$WORKER_LOG_FILE | tr '\r' ' ' | grep '^frame=' | rev | tr -s ' ' | cut -f '9' -d ' ' | rev" >> "profiles/h264-baseline-3-1.currentFrame"
			echo '# iPad (all versions), Apple TV 2 and later, iPhone 4 and later' > "profiles/h264-main-3-1"
			echo 'ffmpeg -i $SOURCE_FILEPATH -movflags +faststart -c:v libx264 -profile:v main -level 3.1 -strict -2 $TARGET_DIRECTORY/$SOURCE_FILENAME 2>$WORKER_LOG_FILE &' >> "profiles/h264-main-3-1"
			echo "ffprobe -i \$SOURCE_FILEPATH -v quiet -print_format json -show_format -print_format json -show_streams | jq '.streams[] | .nb_frames | tonumber' | sort -n | tail -n 1" >> "profiles/h264-main-3-1.totalFrames"
			echo '# Apple TV 3 and later, iPad 2 and later, iPhone 4s and later' > "profiles/h264-main-4-0"
			echo 'ffmpeg -i $SOURCE_FILEPATH -movflags +faststart -c:v libx264 -profile:v main -level 4.0 -strict -2 $TARGET_DIRECTORY/$SOURCE_FILENAME 2>$WORKER_LOG_FILE &' >> "profiles/h264-main-4-0"
			echo "ffprobe -i \$SOURCE_FILEPATH -v quiet -print_format json -show_format -print_format json -show_streams | jq '.streams[] | .nb_frames | tonumber' | sort -n | tail -n 1" >> "profiles/h264-main-4-0.totalFrames"
			echo '# Apple TV 3 and later, iPad 2 and later, iPhone 4s and later' > "profiles/h264-high-4-0"
			echo 'ffmpeg -i $SOURCE_FILEPATH -movflags +faststart -c:v libx264 -profile:v high -level 4.0 -strict -2 $TARGET_DIRECTORY/$SOURCE_FILENAME 2>$WORKER_LOG_FILE &' >> "profiles/h264-high-4-0"
			echo "ffprobe -i \$SOURCE_FILEPATH -v quiet -print_format json -show_format -print_format json -show_streams | jq '.streams[] | .nb_frames | tonumber' | sort -n | tail -n 1" >> "profiles/h264-high-4-0.totalFrames"
			echo '# iPad 2 and later, iPhone 4s and later, iPhone 5c and later' > "profiles/h264-high-4-1"
			echo 'ffmpeg -i $SOURCE_FILEPATH -movflags +faststart -c:v libx264 -profile:v high -level 4.1 -strict -2 $TARGET_DIRECTORY/$SOURCE_FILENAME 2>$WORKER_LOG_FILE &' >> "profiles/h264-high-4-1"
			echo "ffprobe -i \$SOURCE_FILEPATH -v quiet -print_format json -show_format -print_format json -show_streams | jq '.streams[] | .nb_frames | tonumber' | sort -n | tail -n 1" >> "profiles/h264-high-4-1.totalFrames"
			echo '# iPad Air and later, iPhone 5s and later' > "profiles/h264-high-4-2"
			echo 'ffmpeg -i $SOURCE_FILEPATH -movflags +faststart -c:v libx264 -profile:v high -level 4.2 -strict -2 $TARGET_DIRECTORY/$SOURCE_FILENAME 2>$WORKER_LOG_FILE &' >> "profiles/h264-high-4-2"
			echo "ffprobe -i \$SOURCE_FILEPATH -v quiet -print_format json -show_format -print_format json -show_streams | jq '.streams[] | .nb_frames | tonumber' | sort -n | tail -n 1" >> "profiles/h264-high-4-2.totalFrames"
			echo '# All devices iOS devices' > "profiles/hls-h264-baseline-3-0"
			echo 'ffmpeg -i $SOURCE_FILEPATH -movflags +faststart -acodec aac -vcodec libx264 -profile:v baseline -level 3.0 -strict -2 -f segment -vbsf h264_mp4toannexb -flags -global_header -segment_format mpegts -segment_list $TARGET_DIRECTORY/index.m3u8 -segment_time 10 $TARGET_DIRECTORY/part%05d.ts 2>$WORKER_LOG_FILE &' >> "profiles/hls-h264-baseline-3-0"
			echo "ffprobe -i \$SOURCE_FILEPATH -v quiet -print_format json -show_format -print_format json -show_streams | jq '.streams[] | .nb_frames | tonumber' | sort -n | tail -n 1" >> "profiles/hls-h264-baseline-3-0.totalFrames"
			chmod +x profiles/*
			break;;
		No )
			mkdir profiles
			break;;
	esac
done

echo "Setting up assets and workers directory."
mkdir assets workers

echo "Add test video (Big Buck Bunny 60 seconds version)?"
select ANSWER in "No" "Yes"
do
	case $ANSWER in
		Yes )
			echo "Creating assets/big-buck-bunny-test. Remove the folder as soon as you don't need it anymore!"
			mkdir -p assets/big-buck-bunny-test/source/
			echo "Fetching the Bug Buck Bunny 60 seconds version from quirksmode.org"
			cd assets/big-buck-bunny-test/source/
			transcoding_download_binary http://www.quirksmode.org/html5/videos/big_buck_bunny.mp4
			cd - >/dev/null
			echo "Creating job to transcode the video to h264-baseline-3-0"
			mkdir -p assets/big-buck-bunny-test/h264-baseline-3-0
			echo "Creating job to transcode the video to h264-high-4-2"
			mkdir -p assets/big-buck-bunny-test/h264-high-4-2
			echo "Jobs created"
			break;;
		No )
			break;;
	esac
done

if [ -d assets/big-buck-bunny-test ]
then
	echo "Do you want to run the worker 2 times to check the output?"
	select ANSWER in "Yes" "No"
	do
		case $ANSWER in
			Yes )
				TRANSCODING_SH_BIN_DIRECTORY=`dirname $0`
				$TRANSCODING_SH_BIN_DIRECTORY/transcoding.sh start-worker
				$TRANSCODING_SH_BIN_DIRECTORY/transcoding.sh start-worker
				if [ ! -z 'ffprobe assets/big-buck-bunny-test/h264-high-4-2/*.mp4 2>&1 | \grep h264 | \grep High ' ]
				then
					echo "Success: High profile generated!"
				fi

				if [ ! -z 'ffprobe assets/big-buck-bunny-test/h264-high-4-2/*.mp4 2>&1 | \grep h264 | \grep Base' ]
				then
					echo "Success: Base profile generated!"
				fi

				echo "Do you want to remove the test folder for big buck bunny?"
				select ANSWER in "Yes" "No"
				do
					case $ANSWER in
						Yes )
							rm -rf assets/big-buck-bunny-test
							break;;
						No )
							break;;
					esac
				done

				break;;
			No )
				echo "Ok. Please run"
				echo "	transcoding.sh start-worker"
				echo "to start your first transcoding worker. Afterwards the baseline profile is created."
				echo "Run the command again, if you want to generate the high-profile, too."
				break;;
		esac
	done
fi

echo "The transcoding.sh init finished!"

