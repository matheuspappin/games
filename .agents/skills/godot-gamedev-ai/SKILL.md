---
name: godot-gamedev-ai
description: Reference and tool guide for Gamedev AI and Godot 4.7+ development patterns, including shaders, animations, procedural generation, audio, networking, and GDScript best practices.
---

# Godot 4.7+ Gamedev AI Guide & Skills Index

This workspace is integrated with **Gamedev AI** (`addons/gamedev_ai`), providing 65 agentic tools and 25 specialized Godot 4.7+ skill guides.

## In-Engine MCP Server
When Godot Editor is open with `gamedev_ai` enabled, it runs an MCP JSON-RPC server on `127.0.0.1:6543`, bridged to Antigravity via `addons/gamedev_ai/mcp/godot_mcp.py`.

### Available Capabilities:
1. **Node & Scene Manipulation**: `add_node`, `remove_node`, `set_property`, `create_scene`, `instance_scene`, `audit_scene`.
2. **Scripting & Diagnostics**: `create_script`, `edit_script`, `patch_script`, `attach_script`, `get_lsp_diagnostics`.
3. **Audio Synthesis**: `generate_sfx`, `play_sfx_preview`.
4. **Shaders & VFX**: `generate_shader`, `apply_shader_to_node`, `get_shader_presets_list`.
5. **TileMaps & Dungeons**: `generate_procedural_dungeon`, `paint_terrain_cells`, `build_tilemap_layout`, `configure_tileset_atlas`.
6. **Animations & State Machines**: `create_animation`, `setup_spritesheet_animation`, `create_state_machine`, `create_blend_space_2d`, `setup_character_animation_suite`.
7. **Live Execution**: `omni_eval` (runs GDScript in editor context), `get_runtime_errors`, `capture_editor_screenshot`.

## Specialized GDScript & Engine Knowledge Base
Located in `addons/gamedev_ai/skills/`:
- `gdscript_modern_features.md`: Godot 4.7 typed GDScript, lambdas, callables, typed dictionaries/arrays.
- `gdscript_style_guide.md`: Canonical naming, structure, typing conventions.
- `gdscript_deprecated.md`: Obsolete 3.x patterns to avoid.
- `shaders_and_vfx.md`: Custom visual shaders, canvas & spatial passes, uniforms, compute.
- `multiplayer_and_networking_api.md`: High-level multiplayer, RPCs, authority, synchronizers.
- `state_machine_implementation.md`: Clean hierarchical and node-based state machines.
- `physics_and_collision_handling.md`: CharacterBody3D/2D, Jolt physics, collision layers/masks.
- `inventory_and_item_systems.md`: Resource-based modular inventories, stacking, drag-and-drop.
- `audio_management_best_practices.md`: Audio bus layouts, procedural SFX, dynamic mixing.
- `ui_ux_patterns.md`: Control nodes, theme overrides, responsive multi-resolution scaling.
- `level_generation_and_pcg.md`: BSP, Cellular Automata, Wave Function Collapse, procedural dungeons.
- `save_system_and_persistence.md`: Safe JSON/Resource serialization, encryption, version migrations.
