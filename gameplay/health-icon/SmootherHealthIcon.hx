import funkin.play.components.HealthIcon;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import funkin.Conductor;

class SmootherHealthIcon extends HealthIcon
{
  public function new(char:Null<String>, playerId:Int = 0)
  {
    super(char, playerId);
  }

  /**
   * Called on every step.
   * @param curStep The current step number.
   */
  public function onStepHit(curStep:Int):Void
  {
    // Make the icons bop.
    if (bopEvery != 0 && curStep % bopEvery == 0 && shouldBop)
    {
      bopTween?.cancel();
      setGraphicSize(Std.int(this.width + (HealthIcon.HEALTH_ICON_SIZE * this.size.x * HealthIcon.BOP_SCALE)), 0);
      bopTween = FlxTween.num(this.width + (HealthIcon.HEALTH_ICON_SIZE * this.size.x * HealthIcon.BOP_SCALE), HealthIcon.HEALTH_ICON_SIZE * this.size.x, Conductor.instance.stepLengthMs * 0.004,
        {
          ease: FlxEase.quartOut, onComplete: _ -> bopTween = null
        },
        value ->
        {
          setGraphicSize(Std.int(value), 0);
          // Ensure the icon is positioned correctly after updating the hitbox, while its changing size.
          this.updateHitbox();
          this.updatePosition();
        }
      );
      // Ensure the icon is positioned correctly after updating the hitbox.
      this.updateHitbox();
      this.updatePosition();

      this.angle += bopAngle * (playerId == 0 ? 1 : -1);
    }
  }
}