# transcoding.sh

## Folder structure

    assets/
        asset/path/even/with/subfolders/ // asset path
                source // generic profile for the source file
                    123456.mp4
                h264-baseline-3-0 // profile name
                    status.json => contains the transcoding status
                    123456.mp4
    profiles/
        h264-baseline-3-0 // contains all info, how to create the h264-baseline-3-0 profile
    workers
        my.transcoder.hostname/
            F0089ED4-CCB6-4BF4-B430-7E7091CA93C0.pid // random worker id, with the pid
            F0089ED4-CCB6-4BF4-B430-7E7091CA93C0.location // the target directory for the worker
            F0089ED4-CCB6-4BF4-B430-7E7091CA93C0.log // ffmpeg log for the worker
    incoming
        

## Profile file (e.g. `h264-baseline-3-0`)

Will be sourced to generate the profile, might be a ffmpeg call with `&` at the end

``` bash
ffmpeg -i $SOURCE_FILEPATH -c:v libx264 -profile:v baseline -level 3.0 -strict -2 $TARGET_DIRECTORY/$SOURCE_FILENAME &
```

There are some shell variables available in the profiles:

```
SOURCE_FILEPATH=/absolute/path/to/the/source/file.mp4
TARGET_DIRECTORY=/absolute/path/to/the/profile-name-directory
SOURCE_FILENAME=file.mp4
```

## Extra environment variables for profiles

If you need a specific amount of environment variables set for a profile generation, put a file called `profile-name.env`
next to the `profile-name` folder.

The file might look like this:

``` bash
KEY=value
```

Then you will be able to use it in your profile-file at `profiles/profile-name` like this:

``` bash
ffmpeg $KEY
```

## Error handling

If creation of the target file is aborted (with `stop-worker` or `kill -9` to the ffmpeg process),
the entire `$TARGET_DIRECTORY` will be cleaned up. If the `ffmpeg` process dies for other reasons,
the `status.json` file will contain `{"state": "error"}`.

You can check for dead workers with the following command:
``` console
$ transcoding.sh check-workers
B0A846A0-E76D-44DC-89A3-2656AB86857E: alive (20731)
9A5305C2-EAEC-4E14-8DF5-FE8663D49CCE: dead
```

You can enforce cleanup for dead workers (e.g. after reboot) by calling:

``` console
$ transcoding.sh cleanup-workers
``` 

This will remove the target directory's contents and force a new transcoding as soon as somebody starts
`transcoding.sh start-worker`.

## Feature Requests

- add some kind of high prio queue, for even more important files
- add status.json info for mem/cpu etc for current job
- maybe extra error.json, if the job failed
- find better way to ensure that ffmpeg is really finished (instead of sleep 1)