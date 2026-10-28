package ddto.cutscene;

import funkin.play.PlayState;
import funkin.graphics.FunkinSprite;
import funkin.play.cutscene.dialogue.FunkinTypeText;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxTypedSpriteGroup;
import flixel.input.FlxKeyManager;
import flixel.math.FlxMatrix;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import openfl.filters.ShaderFilter;
import flixel.addons.display.FlxRuntimeShader;
import haxe.Json;
import funkin.audio.FunkinSound;
import flixel.text.FlxTextBorderStyle;
import funkin.assets.Assets as NewAssets;
import funkin.assets.Paths as NewPaths;
import openfl.system.System;
import funkin.api.newgrounds.NewgroundsClient;

using String;
using StringTools;
using funkin.util.tools.StringTools;

typedef DialogueFile =
{
  var canSkip:Null<Bool>; //  Determines if this dialogue can be skipped (ex. disabled in obsession ending)
  var initStyle:Null<String>; // Determines what the dialogue style initalizes as
  var startingMusic:Null<String>; // Allows any song to start and fade in like HSC
  var disableBGFade:Null<Bool>; // Self explanitory
  var dialogue:Array<DialogueLine>;
}

typedef DialogueLine =
{
  var isCommand:Null<Bool>; // Either dialogue or command
  var name:Null<String>; // chara name or command name
  var expression:Null<String>; // Exclusive to dialogue
  var string:Null<String>; // used for dialogue or command
  var stringOBS:Null<String>; // used for replacement dialogue when OBS is running
  var key:Null<String>; // used for localized dialogue
  var keyOBS:Null<String>; // used for localized replacement dialogue when OBS is running
  var sound:Null<String>; // Used for the voice clips -- Might be used instead of a seperate command
  var side:Null<String>; // Exclusive to dialogue left or right side or hiding side
  var duration:Null<Float>; // Used for the duration of a cutscene
}

class DokiDialogueBox extends FlxTypedSpriteGroup
{
  final CONVO_PATH:String = 'gameplay/dialogue/doki-conversations';
  var box:FunkinSprite;
  var curCharacter:String = '';
  var prevCharacter:Array<String> = ['monika', 'left'];
  var dialogueData:DialogueFile;

  public var isOBS:Bool = false;

  var isPixel:Bool = false;
  var isEpiphany:Bool = false;
  var canSkip:Bool = true;
  var canFullSkip:Bool = true;
  var playingCutscene:Bool = false;
  // SECOND DIALOGUE FOR THE PIXEL SHIT INSTEAD???
  var swagDialogue:FunkinTypeText;
  var skipText:FlxText;
  var backgroundImage:FunkinSprite;
  var portraitLeft:FunkinSprite;
  var portraitRight:FunkinSprite;
  var blackscreen:FunkinSprite;
  var handSelect:FunkinSprite;
  var bgFade:FunkinSprite;
  var currentDialogue:Int = 0;
  var music:Null<FunkinSound>;

  public var completeCallback:Null<Void->Void> = null;
  public var skippedCallback:Null<Void->Void> = null;

  public function new(id:String, type:String = 'Intro')
  {
    super();

    isEpiphany = PlayState.instance.currentSong.id == 'epiphany';

    isOBS = (!DokiPreferences.selfaware || !NewgroundsClient.isLoggedIn() || NewgroundsClient.user == null);

    if (type != 'End') PlayState.instance.camCutscene.fade(0xFF000000, 0.8, true);

    var dialogueType:String = '${type}Dialogue';
    var jsonDiaString:String = Assets.getText(Paths.json('$CONVO_PATH/$id/$dialogueType'));
    if (!Assets.exists(Paths.json('$CONVO_PATH/$id/$dialogueType')))
    {
      if (!Assets.exists(Paths.json('$CONVO_PATH/$id/IntroDialogue')))
      {
        throw 'Unable to find dialogue JSON for ID: $id';
        return;
      }
    }

    trace('Starting Conversation: $id of type $type');

    dialogueData = Json.parse(jsonDiaString);

    isPixel = (dialogueData.initStyle?.toLowerCase() ?? 'default') == 'pixel';

    backgroundImage = new FunkinSprite();
    backgroundImage.alpha = 0.001;
    insert(0, backgroundImage);

    if (dialogueData.dialogue[currentDialogue].name == 'showbackgroundimage')
    {
      backgroundImage.alpha = 1;
      backgroundImage.loadGraphic(Paths.image('${CONVO_PATH}/bgs/${dialogueData.dialogue[currentDialogue].string}'));
    }

    if (isPixel) backgroundImage.antialiasing = false;

    bgFade = new FunkinSprite(-200, -200).makeSolidColor(Std.int(FlxG.width * 1.3), Std.int(FlxG.height * 1.3), 0xFFB3DFD8);
    bgFade.scrollFactor.set();
    bgFade.alpha = 0.0001;
    add(bgFade);

    if (dialogueData.startingMusic != '')
    {
      final MUSIC_PATH:String = '$CONVO_PATH/music/${dialogueData.startingMusic}/${dialogueData.startingMusic}';
      if (Assets.exists(Paths.music(MUSIC_PATH)))
      {
        music = FunkinSound.load(Paths.music(MUSIC_PATH), 0.0, true, true, true);
        music.fadeIn(1, 0, 0.8);
      }
    }

    if (!(dialogueData.disableBGFade ?? false)) FlxTween.tween(bgFade, {
      alpha: 0.7
    }, 4.98, {
      ease: FlxEase.linear
    });

    if (isPixel) initDialogueStyle(1);
    else
      initDialogueStyle(0);

    // Skipping will now be handled by Funkin's pause menu
    // NEVER FUCKING MIND LMAOOOOOOOOO
    skipText = new FlxText(5, 695, 640, 'Press ${PlayState.instance.controls.getDialogueNameFromToken('BACK', true)} to skip the dialogue.', 40);
    skipText.scrollFactor.set(0, 0);
    skipText.setFormat(Paths.font("ui/fonts/Aller_Rg.ttf"), 20, FlxColor.WHITE, 'left', FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    skipText.borderSize = 2;
    skipText.borderQuality = 1;
    add(skipText);

    if (PlayState.instance.noteStyle.id == 'pixel' || isPixel) skipText.font = Paths.font("ui/fonts/vcr.ttf");

    if (dialogueData.canSkip != null)
    {
      skipText.visible = dialogueData.canSkip;
      canFullSkip = dialogueData.canSkip;
    }

    blackscreen = new FunkinSprite().makeSolidColor(FlxG.width, FlxG.height, FlxColor.BLACK);
    blackscreen.alpha = 0;
    add(blackscreen);

    if (dialogueData.dialogue[currentDialogue].name == 'playcutscene')
    {
      bgFade.visible = false;
      box.visible = false;
      portraitRight.alpha = 0.001;
      portraitLeft.alpha = 0.001;
      swagDialogue.visible = false;
      if (canFullSkip) skipText.visible = false;
    }

    PlayState.instance.camHUD.visible = false;
  }

  var dialogueOpened:Bool = false;
  var dialogueStarted:Bool = false;
  var dialogueEnded:Bool = false;
  var stopspamming:Bool = false;
  var iTime:Float = 0;

  override function update(elapsed:Float)
  {
    if (staticlol != null)
    {
      iTime += elapsed;
      staticlol.setFloat('iTime', iTime);
    }

    if (box.animation.curAnim != null)
    {
      if (box.animation.curAnim.name == 'normalOpen' && box.animation.curAnim.finished)
      {
        box.animation.play('normal');
        dialogueOpened = true;
      }
    }

    if (dialogueOpened && !dialogueStarted)
    {
      startDialogue();
      dialogueStarted = true;
    }

    if (canSkip && !playingCutscene)
    {
      if (PlayState.instance.controls.BACK_P && !stopspamming && canFullSkip && !playingCutscene && dialogueStarted)
      {
        isEnding = true;
        stopspamming = true;
        endinstantly(true);
      }

      if (PlayState.instance.controls.ACCEPT_P && dialogueEnded)
      {
        FunkinSound.playOnce(Paths.sound('gameplay/dialogue/boxes/roses/click-advance'), 0.8);
        enddialogue();
      }
      else if (PlayState.instance.controls.ACCEPT_P && dialogueStarted)
      {
        swagDialogue.skip();
      }
    }

    super.update(elapsed);
  }

  function endinstantly(?skipped:Bool = false)
  {
    // PlayState.instance.cleanupCutscene();
    canSkip = false;
    isEnding = true;
    swagDialogue.skip();

    if (music != null) music.fadeOut(0.5, 0);

    if (skipped && skippedCallback != null) skippedCallback();

    fadeEverything();

    new FlxTimer().start(1.2, function(tmr:FlxTimer)
    {
      dialogueStarted = false;
      completeCallback();
      kill();
    });
  }

  function fadeEverything()
  {
    portraitLeft.alpha = 0.001;
    portraitRight.alpha = 0.001;
    skipText.visible = false;

    if (isPixel)
    {
      new FlxTimer().start(0.2, function(tmr:FlxTimer)
      {
        box.alpha -= 1 / 5;
        backgroundImage.alpha -= 1 / 5;
        bgFade.alpha -= 1 / 5 * 0.7;
        swagDialogue.alpha -= 1 / 5;
        portraitLeft.alpha -= 1 / 5;
        portraitRight.alpha -= 1 / 5;
      }, 5);
    }
    else
    {
      FlxTween.tween(box, {
        alpha: 0
      }, 1.2, {
        ease: FlxEase.linear
      });
      FlxTween.tween(backgroundImage, {
        alpha: 0
      }, 1.2, {
        ease: FlxEase.linear
      });
      FlxTween.tween(bgFade, {
        alpha: 0
      }, 1.2, {
        ease: FlxEase.linear
      });
      FlxTween.tween(swagDialogue, {
        alpha: 0
      }, 1.2, {
        ease: FlxEase.linear
      });
    }
  }

  function enddialogue()
  {
    // PlayState.instance.cleanupCutscene();
    canSkip = true;
    if (dialogueData.dialogue[currentDialogue] == null)
    {
      if (!isEnding)
      {
        canSkip = false;
        isEnding = true;

        if (music != null) music.fadeOut(0.5, 0);
        fadeEverything();

        new FlxTimer().start(1.2, function(tmr:FlxTimer)
        {
          completeCallback();
          kill();
        });
      }
    }
    else
    {
      startDialogue();
    }
  }

  override function kill()
  {
    isPixel = false;
    isOBS = false;
    super.kill();
  }

  var isEnding:Bool = false;
  var isCommand:Bool = false;
  var commands:Array<String> = [
    'playsound',
    'startmusic',
    'endmusic',
    'glitch',
    'autoskip',
    'hideright',
    'hideleft',
    'crash',
    'showbackgroundimage',
    'hidebackground',
    'fadeout',
    'fadein',
    'hidedialogue',
    'hidebgfade',
    'showbgfade',
    'flash',
    'shake',
    'fadecg',
    'swapstyle',
    'styleswap',
    'playcutscene'
  ];

  function getUsername()
  {
    return NewgroundsClient.user?.name;
  }

  function startDialogue():Void
  {
    var curDialogue:DialogueLine = null; // Stealing code from infinite as a test
    var skipEndDialogue:Bool = true;
    do
    {
      curDialogue = dialogueData.dialogue[currentDialogue];
    } while (curDialogue == null);

    if (curDialogue.isCommand != null) isCommand = curDialogue.isCommand;
    else
      isCommand = false;

    if (curDialogue.name != null) curCharacter = curDialogue.name;

    // cleanDialog();
    if (box.visible == false)
    {
      bgFade.visible = true;
      box.visible = true;
      swagDialogue.visible = true;
    }

    // Epiphany username & OBS shit
    var dialogueText:String = curDialogue.string;

    #if FEATURE_LANGUAGE
    if (SaveData.language != 'en-US' && curDialogue.key != null) dialogueText = LangUtil.getString(curDialogue.key, 'dialogue');
    #end

    if (isEpiphany)
    {
      if (isOBS && curDialogue.stringOBS != null)
      {
        dialogueText = curDialogue.stringOBS;

        #if FEATURE_LANGUAGE
        if (SaveData.language != 'en-US' && curDialogue.keyOBS != null) dialogueText = LangUtil.getString(curDialogue.keyOBS, 'dialogue');
        #end
      }
      else
      {
        dialogueText = dialogueText.replace('{USERNAME}', getUsername());
      }
    }

    var commandDuration:Null<Float> = curDialogue.duration;

    if (!isCommand || curCharacter == 'autoskip')
    {
      swagDialogue.resetText(dialogueText);
      swagDialogue.start(0.04);
      swagDialogue.completeCallback = function()
      {
        dialogueEnded = true;
      }

      dialogueEnded = false;
    }

    currentDialogue++;

    if (!isCommand && isPixel)
    {
      FlxTween.cancelTweensOf(portraitRight);
      FlxTween.cancelTweensOf(portraitLeft);
      var portrait:FunkinSprite;
      portrait = (curDialogue.side == 'right' ? portraitRight : portraitLeft);
      var xthingieorig = (curDialogue.side == 'right' ? 647 : 110);
      var xthingienew = (curDialogue.side == 'right' ? 677 : 80);
      var fullChar:String = '$curCharacter-pixel';

      var portraitPath:AssetPath = NewPaths.image('gameplay/dialogue/doki-speakers/$fullChar/$fullChar');
      var portraitXmlPath:AssetsPath = portraitPath.withAssetType('XML');
      if (portraitPath.exists())
      {
        if (curCharacter != prevCharacter[0] && curDialogue.side == prevCharacter[1])
        {
          portrait.alpha = 0.001;
          portrait.x = xthingienew;
        }

        if (curDialogue.side == 'right' && curCharacter == 'monika') portrait.flipX = false;
        else if (curDialogue.side == 'right') portrait.flipX = true;

        portrait.frames = Paths.getSparrowAtlas('gameplay/dialogue/doki-speakers/$fullChar/$fullChar');
        portrait.animation.addByPrefix('hueh', curCharacter.toLowerCase() + '_' + curDialogue.expression, 24, false);
        if (
          portrait.animation.getByName('hueh') == null
          || curDialogue.expression == ''
        ) portrait.animation.addByPrefix('hueh', curCharacter.toLowerCase() + '_neutral', 24, false);
        portrait.animation.play('hueh');

        if (curDialogue.expression != 'gone') FlxTween.tween(portrait, {
          alpha: 1,
          x: xthingieorig
        }, 0.2, {
          ease: FlxEase.linear
        });
        else
          portrait.alpha = 0.001;

        prevCharacter = [curCharacter, curDialogue.side];
      }

      var startswith:String = '';

      if (curDialogue.expression == 'spirit') startswith = 'spirit';
      if (curCharacter.startsWith("monika")) startswith = 'monika';

      swagDialogue.sounds = [FunkinSound.load(Paths.sound('gameplay/dialogue/boxes/roses/click'), 0.8)];
      swagDialogue.color = 0xFF3F2021;
      swagDialogue.borderColor = 0xFFD89494;

      switch (startswith)
      {
        case 'spirit':
          swagDialogue.color = 0xFFFFFFFF;
          swagDialogue.borderColor = 0xFF424242;
          if (box.frames != Paths.getSparrowAtlas('gameplay/dialogue/doki-boxes/dialogue-box-evil'))
          {
            box.frames = Paths.getSparrowAtlas('gameplay/dialogue/doki-boxes/dialogue-box-evil');
            box.animation.addByPrefix('normalOpen', 'Spirit Textbox spawn instance 1', 24, false);
            box.animation.addByIndices('normal', 'Spirit Textbox spawn instance 1', [10], "", 24);
            box.animation.play('normalOpen');
          }
        case 'monika':
          if (box.frames != Paths.getSparrowAtlas('gameplay/dialogue/doki-boxes/dialogue-box-monika'))
          {
            box.frames = Paths.getSparrowAtlas('gameplay/dialogue/doki-boxes/dialogue-box-monika');
            box.animation.addByPrefix('normalOpen', 'Text Box Appear', 24, false);
            box.animation.addByIndices('normal', 'Text Box Appear', [4], "", 24);
            box.animation.play('normalOpen');
          }
        default:
          if (box.frames != Paths.getSparrowAtlas('gameplay/dialogue/doki-boxes/dialogue-box-pixel'))
          {
            box.frames = Paths.getSparrowAtlas('gameplay/dialogue/doki-boxes/dialogue-box-pixel');
            box.animation.addByPrefix('normalOpen', 'Text Box Appear', 24, false);
            box.animation.addByIndices('normal', 'Text Box Appear', [4], "", 24);
            box.animation.play('normalOpen');
          }
      }
    }
    else if (!isCommand && !isPixel)
    {
      box.offset.set(-82, -18.9);
      var startswith:String = '';
      if (curCharacter.startsWith("bf")) startswith = 'bf';
      if (curCharacter.startsWith("sayori")) startswith = 'sayori';
      if (curCharacter.startsWith("monika")) startswith = 'monika';
      if (curCharacter.startsWith("natsuki")) startswith = 'natsuki';
      if (curCharacter.startsWith("yuri")) startswith = 'yuri';
      if (curCharacter.startsWith("gf")) startswith = 'gf';
      if (curCharacter.startsWith("mc") || curCharacter.startsWith("protag")) startswith = 'mc';
      if (curCharacter.startsWith("zipper")) startswith = 'zipper';
      if (curCharacter.startsWith("all")) startswith = 'all';

      var portrait:FunkinSprite; // Basically make this apply to any of em
      portrait = (curDialogue.side == 'right' ? portraitRight : portraitLeft);
      var dialogueSound:String;

      portrait.alpha = 0.001;
      box.animation.play(startswith);
      if (portrait.alpha < 0.9 && curDialogue.expression != 'gone')
      {
        portrait.alpha = 1;
        var portraitPath:AssetPath = NewPaths.image('gameplay/dialogue/doki-speakers/$curCharacter/${curDialogue.expression}');
        var portraitXmlPath:AssetsPath = portraitPath.withAssetType('XML');
        if (portraitXmlPath.exists())
        {
          portrait.frames = NewAssets.getSparrowAtlas(portraitPath);
          portrait.animation.addByPrefix('play', curCharacter + '_' + curDialogue.expression, 24, true);
          portrait.animation.play('play');
        }
        else
        {
          if (portraitPath.exists()) portrait.loadGraphic(portraitPath.toFlxGraphicAsset());
          else
          {
            trace('Lost the expression ${curDialogue.expression} Goin neutral');
            portrait.loadGraphic(Paths.image('gameplay/dialogue/doki-speakers/$curCharacter/neutral'));
          }
        }
      }

      switch (startswith)
      {
        case 'bf' | 'gf' | 'mc':
          if (curDialogue.side == 'left') portrait.flipX = true;
          else
            portrait.flipX = false;

          dialogueSound = '$startswith-text';
          box.animation.play(startswith);
        case 'monika' | 'yuri' | 'sayori' | 'natsuki' | 'zipper':
          if (curDialogue.side == 'right') portrait.flipX = true;
          else
            portrait.flipX = false;

          dialogueSound = '$startswith-text';
          if (curDialogue.expression == 'crazy')
          {
            box.animation.play('yuri_crazy');
            box.offset.set(-55, -12);
          }
          else
            box.animation.play(startswith);
        case 'all':
          if (curDialogue.side == 'right') portrait.flipX = true;
          else
            portrait.flipX = false;

          dialogueSound = 'pixel-text';
          box.animation.play('blankbox');
        default:
          dialogueSound = 'pixel-text';
          box.animation.play('blankbox');
      }
      swagDialogue.sounds = [FunkinSound.load(Paths.sound('gameplay/dialogue/doki-boxes/doki/sounds/' + dialogueSound), 0.8)];
    }

    if (dialogueText == '' && !isCommand) enddialogue();

    // Dialogue commands
    switch (curCharacter)
    {
      case 'playsound':
        FunkinSound.playOnce(Paths.sound('$CONVO_PATH/sounds/${curDialogue.string}'));
      case 'startmusic':
        final MUSIC_PATH:String = '$CONVO_PATH/music/${curDialogue.string}/${curDialogue.string}';
        if (Assets.exists(Paths.music(MUSIC_PATH)))
        {
          music = FunkinSound.load(Paths.music(MUSIC_PATH), 0.0, true, true, true);
          music.fadeIn(1, 0, 0.8);
        }
      case 'endmusic':
        if (music != null) music.fadeOut(0.5, 0);
      case 'glitch':
        skipEndDialogue = false;
        canSkip = false;
        if (curDialogue.string?.toLowerCase() == 'hidedialogue')
        {
          bgFade.visible = false;
          box.visible = false;
          portraitRight.alpha = 0.001;
          portraitLeft.alpha = 0.001;
          swagDialogue.visible = false;
          swagDialogue.sounds = [FunkinSound.load(Paths.sound('gameplay/dialogue/boxes/roses/click'), 0)];
        }
        funnyGlitch();
      case 'autoskip':
        canSkip = false;
        skipEndDialogue = false;
        swagDialogue.completeCallback = enddialogue;
      case 'hideright':
        portraitRight.alpha = 0.001;
      case 'hideleft':
        portraitLeft.alpha = 0.001;
      case 'crash':
        PlayState.instance.endSong(true); // Force the game to save the song/level data before crashing
        System.exit(0);
      case 'showbackgroundimage':
        backgroundImage.loadGraphic(Paths.image('${CONVO_PATH}/bgs/${curDialogue.string}'));
        if (commandDuration != null) FlxTween.tween(commandDuration, {
          alpha: 1
        }, commandDuration, {
          ease: FlxEase.expoOut
        });
        else
          backgroundImage.alpha = 1;
      case 'hidebackground':
        if (commandDuration != null) FlxTween.tween(commandDuration, {
          alpha: 0.001
        }, commandDuration, {
          ease: FlxEase.expoOut
        });
        else
          backgroundImage.alpha = 0.001;
      case 'fadeout':
        canSkip = false;
        blackscreen.alpha = 0;
        if (curDialogue.string?.toLowerCase() == 'hidedialogue')
        {
          bgFade.visible = false;
          box.visible = false;
          portraitRight.alpha = 0.001;
          portraitLeft.alpha = 0.001;
          swagDialogue.visible = false;
          swagDialogue.sounds = [FunkinSound.load(Paths.sound('gameplay/dialogue/boxes/roses/click'), 0)];
          if (canFullSkip) skipText.visible = false;
        }

        FlxTween.tween(blackscreen, {
          alpha: 1
        }, commandDuration, {
          ease: FlxEase.expoOut,
          onComplete: function(twn:FlxTween)
          {
            // blackscreen.alpha = 0; //Might be redundant Undo if it breaks anything
          }
        });
      case 'fadein':
        canSkip = false;
        blackscreen.alpha = 1;

        if (curDialogue.string?.toLowerCase() == 'hidedialogue')
        {
          bgFade.visible = false;
          box.visible = false;
          portraitRight.alpha = 0.001;
          portraitLeft.alpha = 0.001;
          swagDialogue.visible = false;
          swagDialogue.sounds = [FunkinSound.load(Paths.sound('gameplay/dialogue/boxes/roses/click'), 0)];
          if (canFullSkip) skipText.visible = false;
        }

        FlxTween.tween(blackscreen, {
          alpha: 0
        }, commandDuration, {
          ease: FlxEase.expoOut,
          onComplete: function(twn:FlxTween)
          {
            if (canFullSkip && curDialogue.string?.toLowerCase() == 'hidedialogue') skipText.visible = true;
          }
        });
      case 'hidedialogue':
        skipEndDialogue = false;
        dialogueEnded = true;
        bgFade.visible = false;
        box.visible = false;
        portraitRight.alpha = 0.001;
        portraitLeft.alpha = 0.001;
        swagDialogue.visible = false;
      case 'hidebgfade':
        FlxTween.cancelTweensOf(bgFade);
        bgFade.alpha = 0;
      case 'showbgfade':
        bgFade.alpha = 0.7;
      case 'flash':
        PlayState.instance.camCutscene.fade(0xFFFDC1FF, commandDuration, true, true);
      case 'shake':
        PlayState.instance.camCutscene.shake(0.004, commandDuration);
        skipEndDialogue = false;
        enddialogue();
      case 'fadecg':
        // when one CG is on screen and I need the next one called to fade in over the other
      case 'swapstyle' | 'styleswap': // I'm stupid
        skipEndDialogue = false;
        if (curDialogue.string?.toLowerCase() == 'pixel') styleSwap('pixel');
        else
          styleSwap('hueh');
      case 'playcutscene':
        dialogueEnded = true;
        bgFade.visible = false;
        box.visible = false;
        portraitRight.alpha = 0.001;
        portraitLeft.alpha = 0.001;
        swagDialogue.visible = false;
        swagDialogue.sounds = [FunkinSound.load(Paths.sound('gameplay/dialogue/boxes/roses/click'), 0)];

        PlayState.instance.currentSong.playbackCutscene(curDialogue.string?.toLowerCase(), commandDuration);

        if (curDialogue.duration != null)
        {
          playingCutscene = true;

          if (canFullSkip) skipText.visible = false;

          new FlxTimer().start(commandDuration, function(tmr:FlxTimer)
          {
            playingCutscene = false;

            if (canFullSkip) skipText.visible = true;
          });
        }
    }

    if (isCommand && skipEndDialogue)
    {
      if (commandDuration != null && commandDuration > 0 && curCharacter != 'flash')
      {
        new FlxTimer().start(commandDuration, function(tmr:FlxTimer)
        {
          enddialogue();
        });
      }
      else
        enddialogue();
    }
  }

  var staticlol:StaticShader;

  function funnyGlitch():Void
  {
    staticlol = new FlxRuntimeShader(Assets.getText(Paths.frag("ui/shaders/StaticShader")));
    PlayState.instance.camCutscene.filters = [new ShaderFilter(staticlol)];

    FunkinSound.playOnce(Paths.sound('$CONVO_PATH/sounds/glitchin'), 0.6);

    new FlxTimer().start(0.5, function(tmr:FlxTimer)
    {
      PlayState.instance.camCutscene.filters = [];
      staticlol = null;

      enddialogue();
    });
  }

  function styleSwap(style:String = 'normal')
  {
    remove(box);
    remove(portraitLeft);
    remove(portraitRight);
    remove(swagDialogue);
    switch (style)
    {
      default: // Normal cause ya know
        skipText.font = Paths.font("ui/fonts/Aller_Rg.ttf");
        isPixel = false;
        initDialogueStyle(0);
      case 'pixel':
        skipText.font = Paths.font("ui/fonts/vcr.ttf");
        isPixel = true;
        initDialogueStyle(1);
    }

    if (isPixel) backgroundImage.antialiasing = false;

    enddialogue();
  }

  // For dialogue boxes
  var prefixMap:Map<String, String> = [
    "normalOpen" => "Doki Dialogue Blank",
    "blankbox" => "Doki Dialogue noone",
    "bf" => "Doki Dialogue BF",
    "gf" => "Doki Dialogue GF",
    "monika" => "Doki Dialogue Moni",
    "sayori" => "Doki Dialogue Sayo",
    "natsuki" => "Doki Dialogue Natsu",
    "yuri" => "Doki Dialogue Yuri0",
    "yuri_crazy" => "Doki Dialogue Yuri Glitch",
    "mc" => "Doki Dialogue Protag",
    "zipper" => "Doki Dialogue Zipper"
  ];

  function initDialogueStyle(style:Int = 0)
  {
    switch (style)
    {
      default: // Normal will be default, important

        box = new FunkinSprite(-20, 45);
        box.frames = Paths.getSparrowAtlas('gameplay/dialogue/doki-boxes/doki/text-boxes');
        for (name in prefixMap.keys()) box.animation.addByPrefix(name, prefixMap[name], 24, false);

        // Special case left here
        box.animation.addByIndices('normal', 'Doki Dialogue Blank', [9], "", 24);

        // Step 2
        var posY = 50;
        portraitLeft = new FunkinSprite(150, posY);
        portraitLeft.setGraphicSize(Std.int(portraitLeft.width * .9));
        portraitLeft.updateHitbox();
        portraitLeft.scrollFactor.set();
        add(portraitLeft);
        portraitLeft.alpha = 0.001;
        portraitRight = new FunkinSprite(600, posY);
        portraitRight.setGraphicSize(Std.int(portraitRight.width * .9));
        portraitRight.updateHitbox();
        portraitRight.scrollFactor.set();
        add(portraitRight);
        portraitRight.alpha = 0.001;
        box.animation.play('normalOpen');

        box.y += 400;
        box.setGraphicSize(Std.int(box.width * 1.2));
        box.updateHitbox();
        add(box);
        box.screenCenter(0x01);

        swagDialogue = new FunkinTypeText(220, 520, Std.int(box.width * 0.85), "", 28);
        swagDialogue.font = Paths.font("ui/fonts/Aller_Rg.ttf");
        swagDialogue.color = 0xFFFFFFFF;
        swagDialogue.sounds = [FunkinSound.load(Paths.sound('gameplay/dialogue/boxes/roses/click'), 0.8)];
        swagDialogue.setBorderStyle(FlxTextBorderStyle.OUTLINE, FlxColor.BLACK, 1, 1);
        add(swagDialogue);

      case 1: // Pixel
        // Step 1 add box
        box = new FunkinSprite(-20, 45);
        switch (dialogueData.dialogue[currentDialogue].name)
        {
          case 'monika':
            box.frames = Paths.getSparrowAtlas('gameplay/dialogue/doki-boxes/dialogue-box-monika');
            box.animation.addByPrefix('normalOpen', 'Text Box Appear', 24, false);
            box.animation.addByIndices('normal', 'Text Box Appear', [4], "", 24);
            box.animation.play('normalOpen');
          default:
            if (dialogueData.dialogue[currentDialogue]?.expression?.toLowerCase() == 'spirit')
            {
              box.frames = Paths.getSparrowAtlas('gameplay/dialogue/doki-boxes/dialogue-box-evil');
              box.animation.addByPrefix('normalOpen', 'Spirit Textbox spawn instance 1', 24, false);
              box.animation.addByIndices('normal', 'Spirit Textbox spawn instance 1', [10], "", 24);
              box.animation.play('normalOpen');
            }
            else
            {
              box.frames = Paths.getSparrowAtlas('gameplay/dialogue/doki-boxes/dialogue-box-pixel');
              box.animation.addByPrefix('normalOpen', 'Text Box Appear', 24, false);
              box.animation.addByIndices('normal', 'Text Box Appear', [4], "", 24);
              box.animation.play('normalOpen');
            }
        }

        // Step 2 portaits
        portraitLeft = new FunkinSprite(110, -4);
        portraitLeft.frames = Paths.getSparrowAtlas('gameplay/dialogue/doki-speakers/monika-pixel/monika-pixel');
        portraitLeft.animation.addByPrefix('hueh', 'monika_neutral', 24, false);
        portraitLeft.setGraphicSize(Std.int(portraitLeft.width * 6 * 0.9));
        portraitLeft.updateHitbox();
        portraitLeft.antialiasing = false;
        portraitLeft.scrollFactor.set();
        add(portraitLeft);
        portraitLeft.alpha = 0.001;

        portraitRight = new FunkinSprite(647, -4);
        portraitRight.frames = Paths.getSparrowAtlas('gameplay/dialogue/doki-speakers/bf-pixel/bf-pixel');
        portraitRight.animation.addByPrefix('hueh', 'bf_neutral', 24, false);
        portraitRight.setGraphicSize(Std.int(portraitRight.width * 6 * 0.9));
        portraitRight.updateHitbox();
        portraitRight.antialiasing = false;
        portraitRight.scrollFactor.set();
        portraitRight.flipX = true;
        add(portraitRight);
        portraitRight.alpha = 0.001;
        box.animation.play('normalOpen');

        // Scale stuff
        box.setGraphicSize(Std.int(box.width * 6 * 0.9));
        box.antialiasing = false;
        box.updateHitbox();
        add(box);
        box.screenCenter(0x01);

        swagDialogue = new FunkinTypeText(240, 500, Std.int(box.width * 0.6), "", 42);
        swagDialogue.font = Paths.font("ui/fonts/LanaPixel.ttf");
        swagDialogue.borderStyle = FlxTextBorderStyle.SHADOW;
        swagDialogue.color = 0xFF3F2021;
        swagDialogue.borderColor = 0xFFD89494;
        swagDialogue.borderSize = 2;
        swagDialogue.shadowOffset.set(2, 2);
        swagDialogue.sounds = [FunkinSound.load(Paths.sound('gameplay/dialogue/boxes/roses/click'), 0.8)];
        add(swagDialogue);
    }
  }
}
