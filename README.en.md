# SuQing's Undying Amulet

[简体中文](README.md) · [English](README.en.md)

0.4.1 · Project Zomboid B42.22.2 · Single player

Wear the pendant invisibly in its own slot or right-click it to hang it on the backpack you are wearing. Right-clicking a stack mounts one charged amulet. Mounting and removing show a progress bar and commit at completion. Walking, running, or changing backpacks cancels the action. The amulet stays with that backpack. Wearing the same bag again restores its activation.

Version 0.4.1 fixes an error when a character's attachment group is missing the backpack slot. Rescue uses the saved backpack binding, and model synchronization restores the slot when needed.

The amulet shatters at **1 HP or below**, or when a pending fatal zombie drag-down reaches a Lua callback. A worn pendant takes priority over a backpack amulet. The shattered item stays in the original container. It restores **100 HP** and heals body-part injuries. Panic, hunger, fatigue, poisoning, Knox infection and other non-wound conditions are preserved.

Protection and concealment last **three active seconds**. The top of the screen counts down 3 → 2 → 1. Pausing freezes the countdown. Activation clears zombie targets and attempts to cancel grabs and queued drag-down control. The character's earlier protection flags are restored at the end. Native death that completes before a Lua callback, or another mod that kills the player directly, can bypass the amulet.

## Crafting and loot

One Workshop item contains both variants. Enable one at a time and disable the active variant before switching. Both variants use the same item IDs so existing amulets carry over.

| Mod | In-hand crafting materials |
| --- | --- |
| SuQing's Undying Amulet (Default Recipe) | One eligible gemstone, amber, or pearl necklace and 0.5 L of pure animal blood. Pliers are required. The pliers and fluid container are kept. |
| SuQing's Undying Amulet (Simple Recipe) | One stone and one ripped sheet. |

Intact amulets can appear in military crates, jewelry shop display cases, and jewelry stockroom containers. Jewelry shop containers have twice the roll weight of military crates. The sandbox loot rarity affects the final chance. The roll takes place when a container first generates loot.

Debug item IDs are `SuQingUndyingAmulet.UndyingAmulet` and `SuQingUndyingAmulet.BrokenUndyingAmulet`.

## Testing in an isolated save

1. Open the supplied isolated launcher and continue your test save or start a new test character. Use the debug entry for test tools and the normal entry for play. The launcher uses independent saves and keeps the installed PZO runtime.
2. Open the debug Items List and spawn the item from the **SuQingUndyingAmulet** module. Check wearing and backpack mounting, then switch bags and re-equip the original bag.
3. Create an injury in the debug character panel and reduce overall health to **1**. Check for full health, healed wounds, preservation of non-wound conditions, exactly one shattered amulet, and a protection notification.
4. Repeat with a zombie crowd and drag-down enabled. Observe whether a healthy character can recover from the execution sequence, move away, stay concealed for three seconds, and be detected again after expiry.
5. Save and load. Check that broken items remain broken, backpack mounts reappear, and temporary protection has ended.

The intact and shattered amulets have separate icons and dropped models. The pendant is invisible when worn and shows its clip-on model when mounted on a backpack.

## Viewpoint 0.1.7

Use the supplied isolated Viewpoint launcher. In first person, check the held and dropped models, pickup, and inventory action progress. In third person, confirm that wearing is invisible and the backpack attachment is visible. Try the Small, Hiking, and Military Backpacks while standing, turning, and running. Record visible gaps, clipping, or camera obstruction.

## Building locally

Run `python tools/build_workshop.py build/Workshop` to build one Workshop directory with both variants. Use a new destination path.
