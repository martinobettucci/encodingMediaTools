# Encoding Media Tools
This is a repository of public tools I like to share allowing to manage media data in archives.

# Requirements  
* A linux box or comparable
* GNU bash, version 4+  
* HandBrakeCLI (https://handbrake.fr)  
* tovid (http://tovid.wikia.com)  
* exiftool (www.sno.phy.queensu.ca/~phil/exiftool)  

# Release note
This is a set of script I used to write to maintain my media library.  

You should know, time is passing by and MP2 become MP4, MP4 become WEBP, WEBP become H263/4/5... and you have each time to convert all your files from the old format to the new one.  
And believe me **you want** to do it because one day the video format you neglected will be so obsolete that you will not be able to read it anymore and so your precious records will be lost forever.  

So, we all know this is a tedious long and difficult process.  
Those scripts have helped me since a while (like 3 years by now) and they are grown mature enough to be shared with anyone (I hope!).  

# Default parameters
Actually, the hardcoded defaults parameters are (IMHO) the average standard for mid-end camcoder or HD smartphones generated media with H264 encoding.  

Feel free to change these values using the provided methods (the configuration file defaulted in your $HOME directory)

# Workflow description
After having setup your configuration, run the script without parameters to have a look at possible parameters and use-cases.  
All medias, corresponding to the search string defined in the parameters, found in current and all subfolders will be taken in account: please BEWARE this apply to symlinks and hardlinks so you want to have a "--dryrun" before and preview which medias are affected and check you are OK with generated behaviour.

## Running
It will count the number of affected medias and will try to estimate the ETA (will be more accurate after a batch of three to four converted files).

Files are encoded in-place, be sure you'll have enough space and file permissions for the encoding.  
Once encoded, each original file is moved to a special location for backup (defined by the configuration, by default "$PWD/../exifData"): check this target location have enough space and file permissions to handle all your media file temporally.  
Encoded files will be written at the original location eventually with a modified container following your configuration.
Every possible "exif" data should be copied over the converted files but this is not grantee since it depends on the containers involved in the process, so check you have not lost your metadata before wiping the backup data.

A journal of the process will be created in place and in each subfolder reporting some textual data to inspect what happened in the event of a very long process.

The process should be able to restore itself if resumed (but current file conversion will be aborted) so feel free to interrupt it with CTRL+X or CTRL+C (still leave it enough time, 3 to 5 seconds, to handle the exit/int signal to save state).  
It can be resumed by running the same process again using the same parameters in the same root path.

A general operation register file, in your $HOME directory, will be generated having a register of all media being optimised once by those scripts.  
Unless you delete or modify this file whose name depends on your configuration, each media will be converted only once and already converted media will be skipped in the event of a subsequent run on the same root path.

## Installation
Put the script in your path, give it execution permission.
Copy the standard configuration file in your $HOME directory and change its content accordingly to the target system configuration.

# Disclaimer
All rights reserved to the authors of the cited software and trademarks in this document and anywhere in the code of this repository.
This is only a set of scripts driving a set of tools I do not own and not going to distribute: you have to go yourself find them and install them on your box.

This SOFTWARE is provided "as is" and "with all faults."  
THE PROVIDER makes no representations or warranties of any kind concerning the safety, suitability, lack of viruses, inaccuracies, typographical errors, or other harmful components of this SOFTWARE.  
There are inherent dangers in the use of any software, and you are solely responsible for determining whether this SOFTWARE is compatible with your equipment and other software installed on your equipment.  
You are also solely responsible for the protection of your equipment and backup of your data, and THE PROVIDER will not be liable for any damages you may suffer in connection with using, modifying, or distributing this SOFTWARE.  

Lets says it AGAIN: the script is given to the community AS IS and I won't be responsible for any damage it may result from them on any system or systems.
Always inspect the code before running it to check if it fits with target configuration.
