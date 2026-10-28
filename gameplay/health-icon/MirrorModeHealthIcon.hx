package ddto.gameplay;

import funkin.play.components.HealthIcon;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import funkin.Conductor;
import funkin.play.PlayState;
import flixel.math.FlxMath;

class MirrorModeHealthIcon extends HealthIcon
{
  public function new(char:Null<String>, playerId:Int = 0)
  {
    super(char, playerId);
  }

  /**
   * Update the position (and status) of the health icon.
   */
  public function updatePosition():Void
  {
    // Make sure autoUpdate is false if the health icon is not being used in the PlayState.
    if (autoUpdate && PlayState.instance != null)
    {
      switch (playerId)
      {
        case 0: // Boyfriend
          // Update the animation based on the current state.
          updateHealthIcon(HealthIcon.MAXIMUM_HEALTH - PlayState.instance.health);
          // Update the position to match the health bar.
          this.x =
            PlayState.instance.healthBar.x
            + (
              PlayState.instance.healthBar.width * (FlxMath.remapToRange(PlayState.instance.healthBar.value, 0, 2, 0, 100) * 0.01)
              - HealthIcon.POSITION_OFFSET
            );
        case 1: // Dad
          // Update the animation based on the current state.
          updateHealthIcon(PlayState.instance.health);
          // Update the position to match the health bar.
          this.x =
            PlayState.instance.healthBar.x
            + (PlayState.instance.healthBar.width * (FlxMath.remapToRange(PlayState.instance.healthBar.value, 0, 2, 0, 100) * 0.01))
            - (this.width - HealthIcon.POSITION_OFFSET);
      }
      // Keep the icon centered vertically on the health bar.
      this.y = PlayState.instance.healthBar.y - (this.height / 2); // - (PlayState.instance.healthBar.height / 2)
    }
  }
}
