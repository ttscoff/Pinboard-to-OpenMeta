[adore pinboard]: http://brettterpstra.com/i-adore-pinboard/
[delicious script]: http://brettterpstra.com/delicious-spotlight-and-openmeta-tags-revisited/
[pinboard]: http://pinboard.in/
[delibar]: http://www.delibarapp.com/
[caseapps]: http://www.caseapps.com/tags/
[openmeta cli]: http://code.google.com/p/openmeta/downloads/list
[historyhound]: http://www.stclairsoft.com/HistoryHound/
[webbla]: http://www.celmaro.com/webbla/

**Update [April 3rd, 2011]:** The current version, 1.0.4 at the moment, has bugfixes for running without Tags.app installed, more error handling and a new setting for locations where the date format is `dd-mm-yyy`. If you had a previous version and run into trouble, please replace the script with the [latest](#download) and delete your `~/getpinboard.yaml` file to regenerate a new one with the additional localization setting.

This script is for people who want to take advantage of Pinboard--with its full text search, easy privacy settings, accessible API, etc.--yet still want to be able to search their bookmarks in local Spotlight (and similar) searches. While it has the option to save bookmarks with a certain tag as searchable PDF files, it doesn't attempt to replicate the full spectrum of Pinboard features. It's just a way to make your remote bookmarks locally searchable, available system-wide and OpenMeta compatible.

I toyed around for a long time with using safaribookmark files instead of webloc files. They let you store a larger preview image, and you can include full text from websites within the XML of the file. Lots of possibilities there. For many reasons, I decided to stick with these little webloc files. If I want fancier images and web text, I'll use [Webbla][], and if I want comprehensive full text search I'll use [HistoryHound][], both excellent programs in their own right. I want OpenMeta and simplicity, though. If I know I'm looking for a bookmark from Pinboard, I can just go to Delibar and do some searching. The goal is to be able to include my web discoveries in larger searches on my Mac.

### Setup and Features

First, put the script somewhere you can leave it, preferably somewhere in your system path. That's not a huge deal, though, because you'll be supplying an absolute path in most automation cases anyway. Once you have it situated, open Terminal and run `chmod a+x /path/to/your/script.rb`. Now you can run the script from the command line to configure and test.

When you run the script the first time (do it from the command line with `/path/to/script/getpinboard.rb`), it puts a configuration file at `~/getpinboard.yaml`. It will let you know exactly where it is, and will automatically open it in your text editor. You *must* edit the configuration settings before you're ready to run it again. The configuration has options for all of the main features of the script, so these instructions are also going to be the tour. You can edit any of these options at any time. Note that the next time you run the script it will pull in up to 500 of your bookmarks, starting with the oldest. If you decide you didn't like a setting, you may want to trash those files and the database and start over. Try not to let that happen.

#### Configuration options

token (string)
: Pinboard API token; if set, takes precedence over user/password settings below

user and password (string)
: Set these to your Pinboard credentials if you prefer not to use 'token' setting above

dateformat (string)
: Leave this as 'US' if your local date format is `mm-dd-yyyy`. Set it to 'UK' if your date format is `dd-mm-yyyy`.

target (absolute path)
: This is where the webloc files will be collected. It works great with a Dropbox folder, but put it anywhere you like. On my system, I have my `~/Library/Caches/Metadata/Tags/Bookmark` folder (where Tags.app stores its tagged bookmarks) symlinked to `~/Dropbox/Sync/Bookmark`. That Dropbox folder is my target for the script, so I'm saving my Pinboard bookmarks to my Tags folder and still syncing them (and their OpenMeta tags) to my other computers. Further Tags integration will be covered at the end of the options.
: If a folder specified in the config is missing, the script will attempt to create it.

db_location (absolute path)
: This is the location of the bookmarks database. The filename will be `bookmarks.stash`, and it's perfectly fine for it to exist in the same folder as you set for your TARGET.

pdf_location (absolute path)
: If the PDF_TAG below isn't set to false, this is where PDFs of bookmarks with that tag will be created. This requires the latest version of [Paparazzi!](http://derailer.org/paparazzi/) (which does run fine on Snow Leopard).

tag_method (integer 0-2)
: This determines how the OpenMeta tags will be applied. Use 0 to disable, 1 for [Tags.app][caseapps] or 2 for the [OpenMeta CLI utility][openmeta cli].

always_tag (string)
: I like to mark my tags which come from bookmark services for top-level grouping. This setting defaults to "pinboard", but you can change it to anything (or leave it blank).

update\_tags\_db (boolean)
: If you're using Tags.app, you know you can tag a web page with it and it will remember the tags next time you visit that address. That doesn't work with external tools, though, because Tags keeps a separate database for those links. Setting this to true will let the script update the Tags database and keep everything in sync.

create_thumbs (boolean)
: If set to true, this feature will add custom icons to your webloc files using a screengrab of the website and the website's favicon. It looks great in icon and CoverFlow views.
: This is another external requirement. To get thumbnails, you must have [setWeblocThumb](http://hasseg.org/setWeblocThumb/), a free utility for doing just that. The utility must be located at `/usr/local/bin/setWeblocThumb`.
: Note that creating thumbs takes a typical 4-8k webloc file and makes it around 160k average. My bookmarks folder has nearly 200MB of bookmarks in it, tagged and thumbnailed. That's ok with me, but if you want to keep it small and agile, skip the thumbs.

pdf_tag (string)
: The string defined here will determine which bookmarks, if any, are also saved as searchable PDF files. Just use it as a tag and Paparazzi! will download the url in the background to the location you set above.

debug (boolean)
: Leave this off (false), unless you need a little more info about what's going on. It will use Growl and STDOUT to display progress if enabled.

gzip_db (boolean)
: I can't imagine the database file that this generates being large enough to worry about size, but this option will cut the disk space it requires significantly. I leave it off, but it's your choice.

### Optional additions ###

As mentioned above, if you want to create thumbnails for your webloc files from screenshots of the web page, you'll need [setWeblocThumb](http://hasseg.org/setWeblocThumb/), a free utility for doing just that. Its functionality is included in the script, just install the utility and make sure thumbnailing is enabled in the config. The script expects the utility to be located at `/usr/local/bin/setWeblocThumb`.

If you want the option to save bookmarks with a certain tag as fully-searchable PDF files, you'll need the latest (I use the term loosely) version of [Paparazzi!](http://derailer.org/paparazzi/).

You'll also probably want [Growl](http://growl.info/) installed. I can't recall if the command line utility `growlnotify` is set up by default, but that's what the script uses to send notifications. It will live if you don't have it, but it generally won't try to communicate by any other channels when debugging is turned off.

## Running the script

There are a couple of options for automating the script. You can have it run at regular intervals; it stores its last update time and compares it with the Pinboard server before it bothers downloading anything. Once you're up-to-date on your sync, you could run it every 15-30 minutes without any trouble. The easiest way to do that is with `launchd`, and the easiest way to do *that* is with Lingon. If you don't already have it, grab it [from the Mac App Store](http://itunes.apple.com/us/app/lingon/id411211026?mt=12). It's worth the five bucks. Use the wizard to set up a schedule and run the script.

What *I* do is set up [Hazel](http://www.noodlesoft.com/hazel.php) to watch the database file for [Delibar][delibar]. Delibar is my favorite app for bookmarking and searching my online bookmarks. It works wonderfully with Pinboard, and I can't recommend it highly enough. I can hit a key when I'm on a website in any browser and be able to quickly comment, tag and save the page (either privately or publicly) using the same Cocoa interface every time. Anyway, Delibar keeps its database in `~/Library/Application Support/Delibar` and the file is named `DelibarDB.xml`. I simply watch for changes since the last match, and then run the script when one is found. I'm sure you could accomplish something similar with Webbla, or even one of the browser plugins if it modified a local store at all when you add the bookmark.

You could resort to `cron`, or run it manually once in a while, I suppose. It's far handier to have it out of mind, though, and just have your bookmarks show up in OpenMeta and Spotlight searches within minutes of bookmarking them.

## Tips

1. If you imported a ton of bookmarks from Delicious and haven't spent a lot of time "weeding" them, you've probably got a lot of dead links that you'd be better off *not* downloading. Here's a great solution: [stale.py](https://github.com/jparise/stale). It's a Python script that you run locally, and it will traverse your entire collection of links and test them for error responses. You can run it in test mode first, and then turn on the delete mode to get rid of the dead ones. Instructions are at the [bottom of the GitHub page](https://github.com/jparise/stale).
2. Use descriptions *and* tags on things you want to make sure you can find. Clip some text out of the web page or write yourself a note in the description field. These notes are transferred by the script to your Spotlight Comments for the webloc file, making them instantly searchable, in addition to the convenience of tag search.
3. Don't be shy about saving PDFs. If a page is a tutorial that you know you'll need to reference, just go for it. They don't take up much space, they can be annotated easily (seriously, have you tried [Skim](http://skim-app.sourceforge.net/)?), and they allow for full text search locally.
4. Use [Choosy](http://www.choosyosx.com/). With a local store of Spotlight-searchable bookmarks synced with Dropbox, and Choosy to determine what browser you open them in, you have cross-browser, cross-machine support for your entire bookmark collection.
5. The timestamp of the last check is stored in your user's preference files using the `defaults` command. For the purposes of debugging, it's sometimes useful to set that back a bit and force it to update. Just use `getpinboard.rb -r` to set it back 24 hours, or use a number after the -r to specify a number of days to revert.


## Notes and todo

* The script is a one-way sync. All of the pieces are there to start working on a system that would update Pinboard with local deletions and insertions, but I just don't have a need for it. At that point, I might as well make a dedicated application with an SQLite database to do all of this, and that gets way outside the scope of what I started here. Anyway, the only reason I'm not using Webbla for more of this is that it's sandboxed from the rest of the system, and this script can work in tandem with Webbla to fix that.
* Also, the local database created by this script is essentially a text dump, and it can be easily read into a Ruby script and manipulated. It serves as a good backup of all of your Pinboard info, and has some other possibilities as well. Here's a quick [demo script](https://gist.github.com/899757) for outputting an HTML file, and a little tweaking could make it output a format that Safari, Firefox and Chrome can read to import bookmarks. All of the keys and values are there, so you can sift and sort any way you want. Lots of fun to be had, for the adventurous (or easily distracted).
* There is currently no error handling if you don't have [Paparazzi!](http://derailer.org/paparazzi/) installed. If you don't have it and don't want it, delete that block from the AppleScript section. This will be fixed soon.

## Uninstalling

If you need to uninstall the script, remove it from whatever you're using to schedule its activity, delete the script and locate two files:

* `~/getpinboard.yaml` (in your User's home folder)
* `~/Library/Preferences/com.brettterpstra.PinboardTagger.plist` (in your User's Library/Preferences folder)

Hope the script comes in useful for somebody, feel free to let me know if you have any trouble with it.
