Scriptname ASTFillAliasScript extends Quest  

ReferenceAlias[] Property Enemies Auto

Event OnInit()
    Utility.Wait(0.1)
    int i = Enemies.Length
    while i > 0
        i -= 1
        Actor item = Enemies[i].getActorRef()
        if item
        item.StopCombat()
        item.StopCombatAlarm()
      endIf
    endWhile
EndEvent
