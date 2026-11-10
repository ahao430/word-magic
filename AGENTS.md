\
\# Word Magic — AI Coding Agent Instructions\
\
This document defines the development rules and engineering conventions for AI coding agents working on Word Magic.\
\
All AI coding agents, including Claude Code, Codex, and other compatible agents, must follow these instructions.\
\
\---\
\
\## 1. Project Overview\
\
\*\*Project:\*\* Word Magic: The Living World\
\
\*\*Repository:\*\* \`word-magic\`\
\
\*\*Game Engine:\*\* Godot 4.x\
\
\*\*Language:\*\* GDScript\
\
\*\*Target Platforms:\*\*\
\- macOS — primary development platform\
\- Windows — planned release platform\
\
\*\*Game Type:\*\* 2D Fantasy RPG\
\
\*\*Art Style:\*\* HD Pixel Art\
\
Word Magic is a language-driven fantasy RPG where players create magic through natural language and voice input.\
\
Core gameplay includes:\
\
\- Open-world exploration\
\- Natural-language spell creation\
\- Voice-based spell casting\
\- AI-assisted spell interpretation\
\- Combat and magic systems\
\- Environmental interaction\
\- Magic puzzles\
\- Persistent world changes\
\- Procedural exploration\
\- Spell collection and progression\
\
Before making significant changes, read \`plan.md\` and the relevant documents under \`docs/\`.\
\
\---\
\
\## 2. Source of Truth\
\
Follow this priority order when making development decisions:\
\
1\. Explicit instructions from the project owner.\
2\. \`plan.md\` — overall product requirements and roadmap.\
3\. Relevant documents under \`docs/\`.\
4\. Existing architecture and established code conventions.\
5\. This document's general engineering guidelines.\
\
If requirements conflict:\
\
\- Do not silently choose an interpretation.\
\- Identify the conflict.\
\- Explain the impact.\
\- Propose a minimal solution.\
\- Wait for confirmation when the decision changes product behavior or architecture.\
\
Do not invent new gameplay requirements.\
\
Do not treat future roadmap items as requirements for the current development phase.\
\
\---\
\
\## 3. Development Philosophy\
\
Follow these principles:\
\
\### 3.1 Incremental Development\
\
\- Implement one clearly defined feature at a time.\
\- Prefer small, independently testable modules.\
\- Avoid implementing multiple unrelated systems in one task.\
\- Do not generate the entire game in a single operation.\
\- Do not create large amounts of placeholder code without a concrete purpose.\
\
\### 3.2 Vertical Slice First\
\
Prioritize a small but playable forest demo.\
\
The first playable experience should eventually include:\
\
\- A controllable player.\
\- A forest map.\
\- Basic enemies.\
\- Text-based spell casting.\
\- AI spell interpretation.\
\- Basic combat.\
\- Environmental interaction.\
\- A simple magic puzzle.\
\- Save and load.\
\
Do not prioritize large-scale world generation before the core gameplay has been validated.\
\
\### 3.3 Simplicity\
\
\- Prefer built-in Godot functionality.\
\- Avoid unnecessary external services.\
\- Avoid introducing additional runtime dependencies without justification.\
\- Prefer local execution when possible.\
\- Do not introduce a separate backend service unless a real requirement demands it.\
\
\### 3.4 Reversibility\
\
\- Avoid destructive operations.\
\- Preserve original assets.\
\- Do not overwrite user-created files without checking.\
\- Use Git commits at meaningful milestones.\
\- Make data migrations backward-compatible where practical.\
\
\---\
\
\## 4. Repository Structure\
\
Follow the directory organization defined in \`plan.md\`.\
\
Main directories:\
\
\`\`\`text\
word-magic/\
├── project.godot\
├── README.md\
├── AGENTS.md\
├── plan.md\
├── docs/\
├── scenes/\
├── scripts/\
├── resources/\
├── data/\
├── assets/\
├── addons/\
├── tests/\
└── tools/\
\`\`\`\
\
Responsibilities:\
\
\| Directory | Responsibility |\
\|---|---|\
\| \`scenes/\` | Godot scenes |\
\| \`scripts/\` | GDScript implementation |\
\| \`resources/\` | Custom Godot resources |\
\| \`data/\` | JSON, configuration, schemas and game data |\
\| \`assets/\` | Art, audio and visual resources |\
\| \`docs/\` | Architecture and design documentation |\
\| \`tests/\` | Automated tests |\
\| \`tools/\` | Development and asset-processing utilities |\
\| \`addons/\` | Third-party Godot plugins |\
\
Rules:\
\
\- Do not place game logic in arbitrary directories.\
\- Do not mix original source assets with processed game assets.\
\- Do not place runtime save files in the repository.\
\- Do not commit temporary build outputs.\
\- Do not create unnecessary nested directories.\
\- Create directories when their first real implementation is needed.\
\
\---\
\
\## 5. Godot Development Standards\
\
\### 5.1 Engine Compatibility\
\
\- Use Godot 4.x.\
\- Use GDScript as the primary scripting language.\
\- Verify API compatibility with the actual installed Godot version.\
\- Do not use Godot 3.x APIs.\
\- Avoid relying on experimental features unless explicitly approved.\
\
\### 5.2 Scene Design\
\
Prefer composition over large monolithic scenes.\
\
Examples:\
\
\- Player scene owns player movement and animation.\
\- Enemy scene owns enemy-specific behavior.\
\- Spell scenes represent reusable skill implementations.\
\- UI scenes remain independent from gameplay logic.\
\
Avoid putting unrelated gameplay logic inside \`main.tscn\`.\
\
\### 5.3 Script Design\
\
Each script should have a clear responsibility.\
\
Guidelines:\
\
\- Use descriptive class and method names.\
\- Prefer small functions.\
\- Avoid deeply nested conditionals.\
\- Use typed GDScript where practical.\
\- Avoid excessive global state.\
\- Use signals for loosely coupled communication.\
\- Use dependency injection or explicit references when appropriate.\
\
\### 5.4 Autoloads\
\
Use Autoload only for genuinely global services.\
\
Potential candidates:\
\
\- GameManager\
\- EventBus\
\- SaveManager\
\- AudioManager\
\- GameConfig\
\
Do not turn every manager into an Autoload.\
\
Before adding a new Autoload, explain why it needs global lifetime and access.\
\
\### 5.5 Input\
\
Keep input mappings centralized in project settings.\
\
Do not hardcode keyboard input checks across unrelated scripts.\
\
Support keyboard and mouse first.\
\
Voice input and controller support should remain modular.\
\
\---\
\
\## 6. Architecture Boundaries\
\
Keep these systems independent:\
\
\- Game Core\
\- Player\
\- Combat\
\- Magic Engine\
\- AI Providers\
\- Voice Input\
\- World Interaction\
\- Puzzle System\
\- World Memory\
\- Save System\
\- Audio System\
\- UI\
\
Important rules:\
\
1\. UI must not directly implement spell parsing.\
2\. AI providers must not directly manipulate game scenes.\
3\. Spell parsing must not directly apply damage.\
4\. Puzzle validation must not depend on an LLM deciding success.\
5\. World persistence must not depend on temporary scene nodes.\
6\. Audio playback must not be hardcoded into every spell implementation.\
7\. Save data must not depend on unstable scene-tree paths.\
\
Use explicit interfaces and data structures between systems.\
\
Avoid circular dependencies.\
\
\---\
\
\## 7. Magic Engine — Critical Rules\
\
The Magic Engine is the most important system in Word Magic.\
\
Its architecture must remain deterministic and validated.\
\
\### 7.1 Processing Pipeline\
\
\`\`\`text\
Player Input\
&#x20;   |\
&#x20;   v\
Text Normalization\
&#x20;   |\
&#x20;   v\
Exact Cache\
&#x20;   |\
&#x20;   v\
Normalized Cache\
&#x20;   |\
&#x20;   v\
Local Spell Rules\
&#x20;   |\
&#x20;   v\
Semantic Cache\
&#x20;   |\
&#x20;   v\
AI Spell Parser\
&#x20;   |\
&#x20;   v\
Schema Validation\
&#x20;   |\
&#x20;   v\
Skill Validator\
&#x20;   |\
&#x20;   v\
Balance Calculator\
&#x20;   |\
&#x20;   v\
Duplicate Detection\
&#x20;   |\
&#x20;   v\
Spell Factory\
&#x20;   |\
&#x20;   v\
Spell Executor\
\`\`\`\
\
Do not bypass this pipeline.\
\
\### 7.2 AI Is Not an Execution Engine\
\
AI is responsible for understanding language and producing structured spell descriptions.\
\
AI must never:\
\
\- Generate executable GDScript for runtime execution.\
\- Execute arbitrary code.\
\- Directly manipulate the scene tree.\
\- Directly modify player attributes.\
\- Directly apply damage.\
\- Directly change persistent world data.\
\- Bypass skill validation.\
\- Declare puzzle success without rule validation.\
\
Godot owns all gameplay execution.\
\
\### 7.3 Skill Whitelist\
\
Initial supported skill shapes:\
\
\- Projectile\
\- Area\
\- Beam\
\- Field\
\- Tornado\
\- Shield\
\- Summon\
\- Explosion\
\
Supported components may include:\
\
\- Damage\
\- StatusEffect\
\- Movement\
\- Visual\
\- Environment\
\
Unknown components must be rejected safely.\
\
Do not allow arbitrary component names from AI responses.\
\
\### 7.4 Spell Validation\
\
Every parsed spell must be checked for:\
\
\- Valid JSON.\
\- Valid schema version.\
\- Supported element.\
\- Supported shape.\
\- Supported mechanics.\
\- Numeric boundaries.\
\- Maximum area.\
\- Maximum duration.\
\- Maximum damage.\
\- Maximum control strength.\
\- Valid visual recipe.\
\- Valid audio recipe.\
\- Environmental interaction permissions.\
\
Invalid spells must not execute.\
\
\### 7.5 Spell Uniqueness\
\
The current adventure session must prevent duplicate spells.\
\
Use multiple checks:\
\
1\. Exact text.\
2\. Normalized text.\
3\. Semantic similarity.\
4\. Mechanism signature.\
\
Do not classify spells as duplicates based only on their visual shape or damage type.\
\
A cache hit must still pass session-level duplicate detection.\
\
\### 7.6 Balance\
\
All spell costs must be calculated by the game.\
\
AI-provided damage, duration, radius and other parameters are suggestions, not trusted values.\
\
The game must enforce its own balance rules.\
\
\### 7.7 Error Handling\
\
Distinguish:\
\
\- AI parsing failure.\
\- Invalid AI response.\
\- Network failure.\
\- ASR recognition error.\
\- Player cancellation.\
\- Genuine spell instability.\
\
Do not punish players for infrastructure failures or recognition errors.\
\
\---\
\
\## 8. AI Provider Rules\
\
All AI requests must pass through a provider abstraction.\
\
Initial provider categories:\
\
\- Chat Provider\
\- Embedding Provider\
\- ASR Provider\
\
First implementation should prioritize OpenAI-compatible APIs.\
\
Provider configuration may include:\
\
\- API Base URL\
\- API Key\
\- Chat Model\
\- Embedding Model\
\- ASR Provider\
\- ASR Model\
\
Rules:\
\
1\. Do not hardcode API keys.\
2\. Do not log API keys.\
3\. Do not assume a single model provider.\
4\. Handle timeouts.\
5\. Handle rate limits.\
6\. Handle malformed responses.\
7\. Handle unavailable services.\
8\. Do not block the game indefinitely while waiting for network responses.\
9\. Use asynchronous requests where appropriate.\
10\. Do not make AI connectivity mandatory for basic game functionality.\
\
\### Local Fallback\
\
When AI is unavailable:\
\
\- Allow local predefined spells.\
\- Allow local rules and idiom mappings.\
\- Allow cached spells.\
\- Keep movement and combat functional.\
\- Show a useful error message when an unavailable feature is requested.\
\
\---\
\
\## 9. Voice Input Rules\
\
Voice input is a separate input subsystem.\
\
Do not tightly couple ASR implementations with the Magic Engine.\
\
Use a unified interface:\
\
\`\`\`gdscript\
start_recording()\
stop_recording()\
cancel_recording()\
is_available()\
\`\`\`\
\
Provider implementations may include:\
\
\- macOS System ASR\
\- Windows System ASR\
\- Cloud ASR\
\- Whisper.cpp\
\
Rules:\
\
\- Push-to-Talk is the default.\
\- Do not implement always-on microphone listening by default.\
\- Handle microphone permissions.\
\- Handle unavailable microphones.\
\- Handle recognition timeouts.\
\- Handle partial and final recognition results.\
\- Include confidence information when available.\
\- Allow players to confirm or cancel recognized text.\
\- Cancellation must not consume mana.\
\- Recognition errors must not trigger spell backlash.\
\
The configured casting phrase must be configurable rather than hardcoded.\
\
\---\
\
\## 10. World and Puzzle Rules\
\
\### 10.1 Environment Interaction\
\
All environmental changes must go through the Environment Interaction System.\
\
Examples:\
\
\- Growing plants.\
\- Freezing water.\
\- Redirecting water.\
\- Clearing fog.\
\- Moving objects.\
\- Changing weather.\
\
AI must not directly modify environmental state.\
\
\### 10.2 Puzzle Validation\
\
Puzzle rules belong to the game.\
\
A puzzle may define:\
\
\- Required element.\
\- Required mechanism.\
\- Valid target.\
\- Required strength.\
\- Range restrictions.\
\- Activation sequence.\
\- Current state.\
\- Completion conditions.\
\
Multiple valid solutions should be supported where appropriate.\
\
\### 10.3 World Memory\
\
Persistent changes must be represented as serializable data or events.\
\
Do not rely on the existence of a scene node to represent permanent progress.\
\
Examples:\
\
\- Restored bridge.\
\- Activated ancient device.\
\- Recovered forest.\
\- Returned NPC.\
\- Unlocked village.\
\
World changes must be recoverable after restarting the game.\
\
\---\
\
\## 11. Save System Rules\
\
The save architecture has three logical layers:\
\
1\. Permanent world progress.\
2\. Current adventure session.\
3\. Global AI cache.\
\
Rules:\
\
\- Use stable identifiers for persistent objects.\
\- Use map Seed for procedural reconstruction.\
\- Store world modifications as deltas where appropriate.\
\- Separate cache data from save data.\
\- Include save schema versions.\
\- Implement migrations when data structures change.\
\- Do not overwrite the last valid save before a new save is confirmed.\
\- Handle corrupted data safely.\
\- Test save and load together.\
\
Never assume that a scene-tree path is a stable persistent identifier.\
\
\---\
\
\## 12. Asset and Art Rules\
\
The art direction is HD Pixel Art.\
\
Maintain consistency across:\
\
\- Pixel density.\
\- Tile dimensions.\
\- Character proportions.\
\- Camera perspective.\
\- Color palette.\
\- Animation style.\
\- Lighting.\
\- UI elements.\
\
\### 12.1 Asset Sources\
\
Potential sources:\
\
\- Kenney\
\- itch.io\
\- OpenGameArt\
\- Freesound\
\- Sonniss\
\
Before using an asset, verify its license.\
\
\### 12.2 Asset Licensing\
\
Every externally sourced asset must be documented.\
\
Update:\
\
\`assets/manifest/licenses.md\`\
\
Record:\
\
\- Asset name.\
\- Source URL.\
\- Author.\
\- License.\
\- Commercial usage permission.\
\- Attribution requirements.\
\- Modification information.\
\
Do not assume that a free download means unrestricted commercial use.\
\
Do not remove attribution requirements.\
\
\### 12.3 Source and Processed Assets\
\
Keep original files under:\
\
\`assets/source/\`\
\
Processed game assets belong under their corresponding folders.\
\
Never destructively modify the only copy of an original asset.\
\
\### 12.4 AI-Generated Art\
\
Generated images may be used as:\
\
\- Concept art.\
\- Visual references.\
\- UI design references.\
\- Character design references.\
\- Effect design references.\
\
Do not assume a generated concept image is a production-ready sprite sheet.\
\
Before importing generated sprites, check:\
\
\- Transparent background.\
\- Frame consistency.\
\- Sprite alignment.\
\- Pixel grid.\
\- Animation continuity.\
\- Correct perspective.\
\- Appropriate dimensions.\
\
\---\
\
\## 13. Audio Rules\
\
Use a reusable audio recipe system.\
\
Avoid creating a unique sound file for every generated spell.\
\
Audio recipes may combine:\
\
\- Cast sound.\
\- Element sound.\
\- Shape sound.\
\- Impact sound.\
\- Volume.\
\- Pitch variation.\
\
Keep audio playback independent from spell interpretation.\
\
Music should support exploration, combat, boss encounters and village environments.\
\
All external audio must have documented licenses.\
\
\---\
\
\## 14. Coding Style\
\
\### Naming\
\
Use consistent \`snake_case\` for GDScript files, variables and functions.\
\
Examples:\
\
\`\`\`gdscript\
var current_mana: float = 100.0\
\
func cast_spell(spell_data: Dictionary) -> void:\
&#x20;   pass\
\`\`\`\
\
Use descriptive class names.\
\
Avoid unclear abbreviations.\
\
\### Type Safety\
\
Prefer explicit types:\
\
\`\`\`gdscript\
var player_level: int = 1\
var current_mana: float = 100.0\
var is_casting: bool = false\
\`\`\`\
\
Use appropriate types for function arguments and return values.\
\
\### Error Handling\
\
Do not silently ignore errors.\
\
Use clear error messages.\
\
Validate external data before using it.\
\
Handle null values and missing dictionary keys safely.\
\
\### Comments\
\
Comments should explain:\
\
\- Why a decision exists.\
\- Important constraints.\
\- Non-obvious algorithms.\
\- Compatibility requirements.\
\
Avoid comments that simply repeat the code.\
\
\---\
\
\## 15. Testing Requirements\
\
Every new gameplay module should have appropriate tests.\
\
Priority test areas:\
\
\- Text normalization.\
\- Spell schema validation.\
\- Skill validation.\
\- Mana calculations.\
\- Duplicate detection.\
\- Cache behavior.\
\- AI response parsing.\
\- Voice result handling.\
\- Puzzle state transitions.\
\- Environment interactions.\
\- Save and load.\
\- World delta persistence.\
\
\### Testing Rules\
\
Before marking a task complete:\
\
1\. Run relevant tests.\
2\. Run Godot validation or headless checks where available.\
3\. Check runtime errors.\
4\. Verify the affected feature in the game when possible.\
5\. Report anything that could not be tested.\
\
Never claim that something works solely because code generation completed.\
\
Do not hide failing tests.\
\
\---\
\
\## 16. Git and Change Management\
\
Use small, meaningful commits.\
\
Suggested commit prefixes:\
\
\- \`feat:\` New feature\
\- \`fix:\` Bug fix\
\- \`refactor:\` Code restructuring\
\- \`docs:\` Documentation\
\- \`test:\` Tests\
\- \`assets:\` Asset changes\
\- \`chore:\` Maintenance\
\
Examples:\
\
\`\`\`text\
feat: add top-down player movement\
feat: implement basic spell validator\
fix: prevent duplicate spell execution\
docs: update magic engine architecture\
assets: add forest tileset\
\`\`\`\
\
Rules:\
\
\- Do not rewrite unrelated Git history.\
\- Do not force-push unless explicitly authorized.\
\- Do not discard user changes.\
\- Do not modify unrelated files.\
\- Do not commit secrets.\
\- Do not automatically create a GitHub release.\
\
\---\
\
\## 17. Documentation Requirements\
\
Update documentation whenever architecture or behavior changes.\
\
Relevant documents:\
\
\| Document | Responsibility |\
\|---|---|\
\| \`plan.md\` | Overall project plan |\
\| \`docs/architecture.md\` | Technical architecture |\
\| \`docs/game-design.md\` | Gameplay design |\
\| \`docs/magic-system.md\` | Magic Engine |\
\| \`docs/spell-schema.md\` | Spell data protocol |\
\| \`docs/save-system.md\` | Save architecture |\
\| \`docs/world-generation.md\` | Procedural world |\
\| \`docs/audio-design.md\` | Audio design |\
\| \`docs/art-guidelines.md\` | Art specifications |\
\| \`docs/asset-licenses.md\` | Asset licensing |\
\| \`docs/development-roadmap.md\` | Development progress |\
\
Do not update every document for every small code change.\
\
Update only the documents affected by the change.\
\
\---\
\
\## 18. Task Execution Workflow\
\
For every development task, follow this workflow.\
\
\### Step 1: Understand\
\
\- Read the relevant requirements.\
\- Inspect existing code.\
\- Identify dependencies.\
\- Identify affected scenes and scripts.\
\- Check the current Godot version.\
\
\### Step 2: Plan\
\
Provide a short implementation plan.\
\
Identify:\
\
\- Files to create.\
\- Files to modify.\
\- Expected behavior.\
\- Tests.\
\- Risks.\
\
For small, straightforward tasks, keep the plan concise.\
\
\### Step 3: Implement\
\
\- Implement only the requested functionality.\
\- Follow existing architecture.\
\- Reuse existing components.\
\- Avoid unnecessary abstractions.\
\- Avoid unrelated refactoring.\
\
\### Step 4: Validate\
\
\- Run tests.\
\- Check Godot errors.\
\- Verify affected functionality.\
\- Check for regressions.\
\
\### Step 5: Document\
\
Update relevant documentation if required.\
\
\### Step 6: Report\
\
Provide a concise report containing:\
\
\- What was implemented.\
\- Files changed.\
\- Tests executed.\
\- Test results.\
\- Known limitations.\
\- Recommended next task.\
\
Do not claim unverified success.\
\
\---\
\
\## 19. Prohibited Practices\
\
The following are not allowed without explicit approval:\
\
\- Replacing Godot with another engine.\
\- Introducing a mandatory external backend.\
\- Rewriting the whole architecture.\
\- Generating arbitrary executable code from AI responses.\
\- Allowing AI to bypass spell validation.\
\- Allowing AI to directly modify persistent game state.\
\- Implementing always-on microphone listening by default.\
\- Adding unlicensed assets.\
\- Committing API keys.\
\- Deleting original assets.\
\- Performing destructive save migrations without backups.\
\- Implementing future roadmap features prematurely.\
\- Installing large third-party dependencies without justification.\
\- Modifying unrelated project files.\
\
\---\
\
\## 20. Current Development Priority\
\
Follow the roadmap in \`plan.md\`.\
\
Current priority:\
\
\*\*Phase 0 — Project Initialization\*\*\
\
Tasks:\
\
1\. Verify the installed Godot 4.x version.\
2\. Initialize the Godot project in the repository root.\
3\. Create the initial directory structure.\
4\. Configure the main scene.\
5\. Configure input mappings.\
6\. Add a minimal GameManager.\
7\. Add a minimal EventBus if needed.\
8\. Add a basic README.\
9\. Verify the project runs on macOS.\
10\. Commit the initial project structure.\
\
Do not implement the full Magic Engine yet.\
\
Do not start building the complete open world yet.\
\
After Phase 0, move to Phase 1: Basic Game Prototype.\
\
\---\
\
\## 21. Definition of Done\
\
A task is complete only when:\
\
\- Requirements are implemented.\
\- Code follows project conventions.\
\- No unrelated changes were introduced.\
\- Relevant tests pass.\
\- Godot validation is successful where applicable.\
\- Documentation is updated when necessary.\
\- Known limitations are reported.\
\- The implementation can be reviewed and maintained.\
\
\*\*A generated implementation is not automatically a completed implementation.\*\*\
\
\---\
\
\## 22. Final Principle\
\
Word Magic is a language-driven game, not an AI-generated code playground.\
\
The AI interprets the player's imagination.\
\
The game engine owns the rules, state, balance, persistence and execution.\
\
Keep the architecture safe, modular, testable and extensible.\
\
\*\*Words become magic. Imagination shapes the world.\*\*\

