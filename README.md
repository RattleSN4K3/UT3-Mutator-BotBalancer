BotBalancer
==========================

A mutator for **Unreal Tournament 3** which balances the teams based on set conditions (Players vs. Bots, Bot-ratio, Map recommended players, ...).


# Install

 - Download the [lastest version](/../../releases/latest)
 - Extract the zip file to your UT3 folder. For instance:  
  `%userprofile%\Documents\My Games\Unreal Tournament 3\UTGame`  
  or manually move the content to the following subfolders:
- `UTBotBalancer.ini` to `.\Config`
- `BotBalancer.u` to `.\Published\CookedPC\Script`
- `BotBalancer.int` to `.\Published\CookedPC\Localization`


# Usage

__Method 1:__
 - Start the game
 - Add the following mutator: `BotBalancer`
 - Enjoy.

__Method 2:__
 - Add the following line to the command line arguments (or your shortcut, server command line, ...):  
   `?mutator=BotBalancer.BotBalancerMutator`
 - **Note:** Split multiple mutators by the character `,` (*comma*)
   
__Method 3:__
 - Open the *WebAdmin* interface
 - Navigate to the following address `/ServerAdmin/current/change`
 - Enable `BotBalancer`
 - Click *Change game*
 - After the reload, the mutator will be active.


# Compiling

The mutator comes with all the needed files. Before the code can be compiled, the engine must be aware of the installed source files and the source files must be placed into the correct folder.

## Setup

For easy referencing, `%basedir%` would be the local profile folder `%userprofile%\Documents\My Games\Unreal Tournament 3\UTGame`

- Download the [latest source files](/../../archive/master.zip)
- Extract the zipped source files
- Create a folder named `BotBalancer` into the source folder `%basedir%\Src`
- Copy/symlink the **`Classes`** folder of the source files into `%basedir%\Src\BotBalancer`
  (if the source folder is not already extracted into `%basedir%\Src`)
- Copy/symlink `Config\UTBotBalancer.ini` to `%basedir%\Src\Config`
- Copy/symlink `Localization\BotBalancer.int` to **both** folders:  
 - `%basedir%\Published\CookedPC\Localization`
 - `%basedir%\Unpublished\CookedPC\Localization`

And finally add the package to the compiling packages of the engine.

- Open `%basedir%\Config\UTEditor.ini`
- Search for the section `[ModPackages]`
- Add **`ModPackages=BotBalancer`** at the end of the section
(before the next section starts)

## Make

The script files contain several lines of debug code. The code can be compiled in two ways which one would strip any of these debug lines from the code - this would be the *final release* mutator.

### Debug 

- Compile the packages with:
`ut3 make -debug`


### Final release

- Compile the packages with:
`ut3 make -final_release`

## Testing

Copy/move `%basedir%\Unpublished\CookedPC\Script\BotBalancer.u` to the public script folder `%basedir%\Published\CookedPC\Script\` and run the game.

Without copying/moving the file, the game must be started with the *UseUnpublished* command line argument:
`ut3 -useunpublished`


# License
Available under [the MIT license](http://opensource.org/licenses/mit-license.php).

# Author
RattleSN4K3

