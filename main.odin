package game

import "core:unicode/utf8/utf8string"
import "core:encoding/uuid"
import "core:math/rand"
import "core:math"
import rl "vendor:raylib"

MAX_ENTITIES :: 100

GAME_WIDTH :: 224
GAME_HEIGHT :: 256
GAME_SCALE_FACTOR :: 4.0

PROJECTILE_OFFSET :: 5
PLAYER_PROJECTILE_SPEED :: -2.0
ROWS_OF_BLUE_ENEMIES :: 3
COLUMNS_OF_BLUE_ENEMIES ::  10
COLUMNS_OF_PURPLE_ENEMIES :: 8
BLUE_ENEMY_STARTING_Y :: 40.0
PURPLE_ENEMY_STARTING_Y :: 24.0
ENEMY_SPACING :: 16.0
ENEMY_SIZE :: 16.0
SPRITE_TO_HITBOX_SCALE :: 0.4
ENEMY_TICKS_PER_DIRECTION :: 400
TICK_DURATION :: 0.01

BASE_PLAYER_SPRITE : rl.Rectangle : {1, 70, 16, 16}
BASE_BULLET_SPRITE : rl.Rectangle : {200, 97, 1, 2}
BASE_BLUE_ENEMY_SPRITE : rl.Rectangle : {1, 34, 16, 16}
BASE_PURPLE_ENEMY_SPRITE : rl.Rectangle : {1, 17, 16, 16}
BASE_ENEMY_DEATH_SPRITE : rl.Rectangle : { 61, 70, 16, 16 }
BASE_PLAYER_DEATH_SPRITE : rl.Rectangle : { 1, 87, 32, 32 }

DIVING_CHANCE :: 2
BLUE_ENEMY_SHOOT_CHANCE :: 25
PURPLE_ENEMY_SHOOT_CHANCE :: 50
MAX_STARS :: 50

GameState :: enum
{
    MAIN_MENU,
    IN_GAME,
    GAME_OVER,
}

GameMode :: enum
{
    SOLO,
    COOP,
}

EntityType :: enum
{
    PLAYER,
    ENEMY,
    PROJECTILE
}

EnemyType :: enum
{
    BLUE,
    PURPLE
}

EnemyBehaviour :: enum
{
    IN_FORMATION,
    DIVING
}

ProjectileType :: enum
{
    PLAYER_BULLET,
    ENEMY_BULLET
}

AIAllyState :: enum
{
    STILL,
    MOVING_LEFT,
    MOVING_RIGHT
}
PlayerData :: struct
{
    currentProjectiles: u8,
    deathAnimation: Animation,
    
}

EnemyData :: struct
{
    enemyType: EnemyType,
    behaviour: EnemyBehaviour,
    deathAnimation: Animation,
    movementAnimation: Animation,
    diveStartTick: u32,
}

ProjectileData :: struct
{
    projectileType: ProjectileType,
    ownerID: u8,
}

EntityData :: union
{
    PlayerData,
    EnemyData,
    ProjectileData,
}

EntityState :: enum
{
    ALIVE,
    DYING,

}
Entity :: struct
{
    position: rl.Vector2,
    velocity: rl.Vector2,
    type: EntityType,
    size: f32,
    id: u8,
    data: EntityData,
    state: EntityState,
    baseSprite: rl.Rectangle
}

Star :: struct
{
    position: rl.Vector2,
    speed: f32,
}

Animation :: struct
{
    frames: []rl.Rectangle,
    frameCount: u8,
    currentFrame: u8,
    ticksPerFrame: u8,
    lastFrameChange: u32,
}
Assets :: struct
{
    playerShoot: rl.Sound,
    fighterLoss: rl.Sound,
    hitEnemy: rl.Sound,
    battleTheme: rl.Sound,
    gameOver: rl.Sound,
    spriteSheet: rl.Texture2D,
    blueEnemyMovement: Animation,
    purpleEnemyMovement: Animation,
    enemyDeath: Animation,
    playerDeath: Animation,
}

GameData :: struct
{
    gameState: GameState,
    gameMode: GameMode,
    entities: [MAX_ENTITIES]Entity,
    entityCount: u8,
    maxPlayerProjectiles: u8,
    currentDivingEnemies: u8,
    maxDivingEnemies: u8,
    stars: [MAX_STARS]Star,
    AIallyState: AIAllyState
    

}

InitializeGameData :: proc(gameData: ^GameData)
{
    gameData.gameState = .MAIN_MENU
    gameData.gameMode = .SOLO
    gameData.entityCount = 0
    gameData.maxPlayerProjectiles = 1
    gameData.currentDivingEnemies = 0
    gameData.maxDivingEnemies = 5
    gameData.AIallyState = .STILL
}

loadAssets :: proc(assets: ^Assets)
{
    assets.playerShoot = rl.LoadSound("res/Shoot.mp3")
    assets.fighterLoss = rl.LoadSound("res/Fighter Loss.mp3")
    assets.hitEnemy = rl.LoadSound("res/Hit Enemy.mp3")
    assets.battleTheme = rl.LoadSound("res/Battle Theme.mp3")
    assets.gameOver = rl.LoadSound("res/Game Over.mp3")

    spritesheetImage : rl.Image = rl.LoadImage("res/Spritesheet.png");
    rl.ImageFormat(&spritesheetImage, rl.PixelFormat.UNCOMPRESSED_R8G8B8A8);
    rl.ImageColorReplace(&spritesheetImage, rl.BLACK, { 0, 0, 0, 0 });
    assets.spriteSheet = rl.LoadTextureFromImage(spritesheetImage);
    rl.UnloadImage(spritesheetImage);
    rl.SetTextureFilter(assets.spriteSheet, .POINT);

    // Animations
    loadAnimation(&assets.blueEnemyMovement, 3, BASE_BLUE_ENEMY_SPRITE, 1, 50);
    loadAnimation(&assets.purpleEnemyMovement, 3, BASE_PURPLE_ENEMY_SPRITE, 1, 50);
    loadAnimation(&assets.enemyDeath, 4, BASE_ENEMY_DEATH_SPRITE, 1, 15);
    loadAnimation(&assets.playerDeath, 4, BASE_PLAYER_DEATH_SPRITE, 1, 15);
}

loadAnimation :: proc(animation: ^Animation, frameCount: u8, baseFrame: rl.Rectangle, spacing: f32, ticksPerFrame: u8)
{
    animation.frames = make([]rl.Rectangle, frameCount)
    for i : u8 = 0; i < frameCount; i += 1
    {
        animation.frames[i] = { baseFrame.x + f32(i) * (baseFrame.width + spacing), baseFrame.y, baseFrame.width, baseFrame.height };
    }
    animation.frameCount = frameCount 
    animation.currentFrame = 0
    animation.ticksPerFrame = ticksPerFrame
    animation.lastFrameChange = 0 
}

StartGame :: proc(gameData: ^GameData, assets: ^Assets)
{
    gameData.entities[0] = { type = .PLAYER, state = .ALIVE, position = {gameData.gameMode == .COOP ? 92.0 : 112.0, 240}, velocity = {0, 0}, size = 16, baseSprite = BASE_PLAYER_SPRITE, id = 0}
    gameData.entities[0].data = PlayerData{ currentProjectiles = 0, deathAnimation = assets.playerDeath }
    gameData.entityCount += 1

    if (gameData.gameMode == .COOP)
    {
        gameData.entities[1] = { type = .PLAYER, state = .ALIVE, position = {132, 240}, velocity = {0, 0}, size = 16, baseSprite = BASE_PLAYER_SPRITE, id = 1}
        gameData.entities[1].data = PlayerData{ currentProjectiles = 0, deathAnimation = assets.playerDeath }
        gameData.entityCount += 1
    }

    for i := 0; i < ROWS_OF_BLUE_ENEMIES; i += 1
    {
        for j := 0; j < COLUMNS_OF_BLUE_ENEMIES; j += 1
        {
            gameData.entities[gameData.entityCount] = { type = .ENEMY, state = .ALIVE, position = {f32(GAME_WIDTH / 2.0 - COLUMNS_OF_BLUE_ENEMIES * ENEMY_SPACING / 2.0 + j * ENEMY_SPACING), f32(BLUE_ENEMY_STARTING_Y + i * ENEMY_SPACING)}, velocity = {0.1, 0}, size = ENEMY_SIZE, id = gameData.entityCount, baseSprite = BASE_BLUE_ENEMY_SPRITE }
            gameData.entities[gameData.entityCount].data = EnemyData{ enemyType = .BLUE, behaviour = .IN_FORMATION, deathAnimation = assets.enemyDeath, movementAnimation = assets.blueEnemyMovement }
            gameData.entityCount += 1
        }
    }

    for j := 0; j < COLUMNS_OF_PURPLE_ENEMIES; j += 1
    {
        gameData.entities[gameData.entityCount] = { type = .ENEMY, state = .ALIVE, position = {f32(GAME_WIDTH / 2.0 - COLUMNS_OF_PURPLE_ENEMIES * ENEMY_SPACING / 2.0 + j * ENEMY_SPACING), PURPLE_ENEMY_STARTING_Y}, velocity = {0.1, 0}, size = ENEMY_SIZE, id = gameData.entityCount, baseSprite = BASE_PURPLE_ENEMY_SPRITE };
        gameData.entities[gameData.entityCount].data = EnemyData{ enemyType = .PURPLE, behaviour = .IN_FORMATION, deathAnimation = assets.enemyDeath, movementAnimation = assets.purpleEnemyMovement }
        gameData.entityCount += 1
    }

    for i := 0; i < MAX_STARS; i += 1
    {
        gameData.stars[i] = 
        {
            position = { f32(rand.int_max(GAME_WIDTH)), f32(rand.int_max(GAME_HEIGHT)) },
            speed = 0.8,
        }
    }
}

HandleInput :: proc(gameData: ^GameData, assets: ^Assets)
{
    switch gameData.gameState
    {
        case .MAIN_MENU:
            mousePosition : rl.Vector2 = rl.GetMousePosition()
            gameMousePosition : rl.Vector2 = {mousePosition.x / GAME_SCALE_FACTOR, mousePosition.y / GAME_SCALE_FACTOR}
            soloButton : rl.Rectangle = { GAME_WIDTH / 2 - 75, GAME_HEIGHT / 2 - 75, 150, 50 };
            coOpButton : rl.Rectangle = { GAME_WIDTH / 2 - 75, GAME_HEIGHT / 2, 150, 50 };
            if rl.CheckCollisionPointRec(gameMousePosition, soloButton) && rl.IsMouseButtonPressed(.LEFT)
            {
                gameData.gameState = .IN_GAME;
                gameData.gameMode = .SOLO;
                StartGame(gameData, assets);
            }
            else if rl.CheckCollisionPointRec(gameMousePosition, coOpButton) && rl.IsMouseButtonPressed(.LEFT)
            {
                gameData.gameState = .IN_GAME;
                gameData.gameMode = .COOP;
                StartGame(gameData, assets);
            }
        case .IN_GAME:
            if gameData.entities[0].type == .PLAYER
            {
                if rl.IsKeyDown(.LEFT) do gameData.entities[0].velocity = { -1.0, 0 }
                else if rl.IsKeyDown(.RIGHT) do gameData.entities[0].velocity = { 1.0, 0 }
                else do gameData.entities[0].velocity = { 0, 0 }
                if rl.IsKeyPressed(.LEFT_CONTROL) do ShootProjectile(gameData, &gameData.entities[0], assets)
            }
        case .GAME_OVER:
    }
}

Update :: proc(gameData: ^GameData, currentTick: u32, assets: ^Assets)
{
    for i : u8 = 0; i < gameData.entityCount; i += 1
    {
        gameData.entities[i].position.x += gameData.entities[i].velocity.x
        gameData.entities[i].position.y += gameData.entities[i].velocity.y

        switch gameData.entities[i].type
        {
            case .PLAYER: UpdatePlayer(gameData, i, currentTick, assets)
            case .ENEMY: UpdateEnemy(gameData, i, currentTick, assets)
            case .PROJECTILE: UpdateProjectile(gameData, i, assets)
        }
    }

    if gameData.gameMode == .COOP && gameData.entities[1].type == .PLAYER
    {
        UpdateAllyAI(gameData, assets);
    }
    
    for i := 0; i < MAX_STARS; i += 1
    {
        gameData.stars[i].position.y += gameData.stars[i].speed
        if gameData.stars[i].position.y > GAME_HEIGHT
        {
            gameData.stars[i].position.y = 0
            gameData.stars[i].position.x = f32(rand.int_max(GAME_WIDTH))
        }
    }

    anyPlayerAlive := 0
    for j : u8 = 0; j < gameData.entityCount; j += 1
    {
        if gameData.entities[j].type == .PLAYER && (gameData.entities[j].state == .ALIVE || gameData.entities[j].state == .DYING)
        {
            anyPlayerAlive = 1;
            break;
        }
    }
    if anyPlayerAlive == 0
    {
        gameData.gameState = .GAME_OVER;
        return;
    }
}

UpdatePlayer :: proc(gameData: ^GameData, id: u8, currentTick: u32, assets: ^Assets)
{
    playerData := &gameData.entities[id].data.(PlayerData)
    if gameData.entities[id].state == .DYING
    {
        if (currentTick - playerData.deathAnimation.lastFrameChange >= u32(playerData.deathAnimation.ticksPerFrame))
        {
            playerData.deathAnimation.currentFrame = (playerData.deathAnimation.currentFrame + 1);
            playerData.deathAnimation.lastFrameChange = currentTick;
        }
        if (playerData.deathAnimation.currentFrame >= playerData.deathAnimation.frameCount)
        {
            KillEntity(gameData, id);
        }
        return;
    }
    
}

UpdateEnemy :: proc(gameData: ^GameData, id: u8, currentTick: u32, assets: ^Assets)
{
    enemyData := &gameData.entities[id].data.(EnemyData)
    if gameData.entities[id].state == .DYING
    {
        if (currentTick - enemyData.deathAnimation.lastFrameChange >= u32(enemyData.deathAnimation.ticksPerFrame))
        {
            enemyData.deathAnimation.currentFrame = (enemyData.deathAnimation.currentFrame + 1)
            enemyData.deathAnimation.lastFrameChange = currentTick
        }
        if enemyData.deathAnimation.currentFrame >= enemyData.deathAnimation.frameCount do KillEntity(gameData, id)
        return
    }

    switch enemyData.behaviour
    {
        case .IN_FORMATION:
            if currentTick % ENEMY_TICKS_PER_DIRECTION == 0
            {
                gameData.entities[id].velocity.x *= -1
            }
            if gameData.currentDivingEnemies < gameData.maxDivingEnemies
            {
                divingChance := rand.int_max(10000) 

                if divingChance < DIVING_CHANCE
                {
                    enemyData.behaviour = .DIVING
                    enemyData.diveStartTick = currentTick
                    gameData.currentDivingEnemies += 1
                }
            }
        case .DIVING:
            shootChance := rand.int_max(10000) 
            t := f32(currentTick - enemyData.diveStartTick) * (TICK_DURATION * 2.0);
            if enemyData.enemyType == .BLUE
            {
                gameData.entities[id].velocity = { math.cos(t) * 1.5, math.sin(t * 0.5) * 0.5 };
                if (shootChance < BLUE_ENEMY_SHOOT_CHANCE)
                {
                    ShootProjectile(gameData, &gameData.entities[id], assets);
                }
            }
            else if enemyData.enemyType == .PURPLE
            {
                gameData.entities[id].velocity = { math.cos(t) * 3.5, math.sin(t * 0.7) * 0.7};
                if (shootChance < PURPLE_ENEMY_SHOOT_CHANCE)
                {
                    ShootProjectile(gameData, &gameData.entities[id], assets);
                }
            }
    }

    if (currentTick - gameData.entities[id].data.(EnemyData).movementAnimation.lastFrameChange >= u32(gameData.entities[id].data.(EnemyData).movementAnimation.ticksPerFrame))
    {
        enemyData.movementAnimation.currentFrame = (gameData.entities[id].data.(EnemyData).movementAnimation.currentFrame + 1) % gameData.entities[id].data.(EnemyData).movementAnimation.frameCount;
        enemyData.movementAnimation.lastFrameChange = currentTick;
    }
}

UpdateProjectile :: proc(gameData: ^GameData, id: u8, assets: ^Assets)
{
    if gameData.entities[id].position.y < 0 || gameData.entities[id].position.y > GAME_HEIGHT
    {
        if gameData.entities[id].data.(ProjectileData).projectileType == .PLAYER_BULLET
        {
            playerID : u8 = gameData.entities[id].data.(ProjectileData).ownerID
            if player, ok := &gameData.entities[playerID].data.(PlayerData); ok 
            {
                player.currentProjectiles -= 1
            }
        }
        KillEntity(gameData, id)
        return
    }

    switch gameData.entities[id].data.(ProjectileData).projectileType
    {
        case .PLAYER_BULLET:
            for i : u8 = 0; i < gameData.entityCount; i += 1
            {
                if gameData.entities[i].type == .ENEMY && CheckCollision(gameData.entities[i], gameData.entities[id])
                {
                    playerID : u8 = gameData.entities[id].data.(ProjectileData).ownerID
                    if player, ok := &gameData.entities[playerID].data.(PlayerData); ok 
                    {
                        player.currentProjectiles -= 1
                    }
                    KillEntity(gameData, id)
                    if i == gameData.entityCount do i = id;
                    gameData.entities[i].state = .DYING
                    rl.PlaySound(assets.hitEnemy);
                    return
                }
            }
        case .ENEMY_BULLET:
            for i : u8 = 0; i < gameData.entityCount; i += 1
            {
                if gameData.entities[i].type == .PLAYER && CheckCollision(gameData.entities[i], gameData.entities[id])
                {
                    rl.PlaySound(assets.fighterLoss);
                    gameData.entities[i].state = .DYING
                    return
                }
            }
    }
}

UpdateAllyAI :: proc(gameData: ^GameData, assets: ^Assets)
{
    actionChance := rand.int_max(10000) 
    switch gameData.AIallyState
    {
    case .STILL:
        ShootProjectile(gameData, &gameData.entities[1], assets);
        if actionChance < 4000 do gameData.AIallyState = .MOVING_LEFT;
        if actionChance > 6000 do gameData.AIallyState = .MOVING_RIGHT;
    case .MOVING_LEFT:
        gameData.entities[1].velocity = { -1.0, 0 };
        if gameData.entities[1].position.x < 0.0 || actionChance > 9900 do gameData.AIallyState = .MOVING_RIGHT;
        if actionChance < 100 do gameData.AIallyState = .STILL
    case .MOVING_RIGHT:
        gameData.entities[1].velocity = { 1.0, 0 };
        if gameData.entities[1].position.x > GAME_WIDTH || actionChance > 9900 do gameData.AIallyState = .MOVING_LEFT;
        if actionChance < 100 do gameData.AIallyState = .STILL
    }
}

Draw :: proc(target: rl.RenderTexture2D, gameData: ^GameData, assets: ^Assets)
{
    rl.BeginTextureMode(target)
    rl.ClearBackground(rl.BLACK)

    switch gameData.gameState
    {
        case .MAIN_MENU: 
            soloButton: rl.Rectangle = { GAME_WIDTH / 2 - 75, GAME_HEIGHT / 2 - 75, 150, 50}
            coopButton: rl.Rectangle = { GAME_WIDTH / 2 - 75, GAME_HEIGHT / 2, 150, 50 }

            rl.DrawRectangleRec(soloButton, rl.WHITE)
            rl.DrawRectangleRec(coopButton, rl.WHITE)

            rl.DrawText("SOLO", GAME_WIDTH / 2 - rl.MeasureText("SOLO", 16) / 2, GAME_HEIGHT / 2 - 60, 16, rl.BLUE)
            rl.DrawText("CO-OP", GAME_WIDTH / 2 - rl.MeasureText("CO-OP", 16) / 2, GAME_HEIGHT / 2 + 15, 16, rl.BLUE)
        
        case .IN_GAME:
            if !rl.IsSoundPlaying(assets.battleTheme) do rl.PlaySound(assets.battleTheme)
            for i : u8 = 0; i < gameData.entityCount; i += 1
            {
                spritePosition: rl.Rectangle = { f32(i32(gameData.entities[i].position.x - gameData.entities[i].size / 2.0)), f32(i32(gameData.entities[i].position.y - gameData.entities[i].size / 2.0)), gameData.entities[i].size, gameData.entities[i].size }
                switch gameData.entities[i].type
                {
                    case .PLAYER:
                        if gameData.entities[i].state == .ALIVE
                        {
                            rl.DrawTexturePro(assets.spriteSheet, gameData.entities[i].baseSprite, spritePosition, { 0, 0 }, 0.0, rl.WHITE);
                        }
                        else if gameData.entities[i].state == .DYING
                        {
                            rl.DrawTexturePro(assets.spriteSheet, gameData.entities[i].data.(PlayerData).deathAnimation.frames[gameData.entities[i].data.(PlayerData).deathAnimation.currentFrame], spritePosition, { 0, 0 }, 0.0, rl.WHITE);
                        }                 
                    case .ENEMY:
                        if gameData.entities[i].state == .ALIVE
                        {
                            rl.DrawTexturePro(assets.spriteSheet, gameData.entities[i].data.(EnemyData).movementAnimation.frames[gameData.entities[i].data.(EnemyData).movementAnimation.currentFrame], spritePosition, { 0, 0 }, 0.0, rl.WHITE);
                        }
                        else if gameData.entities[i].state == .DYING
                        {
                            rl.DrawTexturePro(assets.spriteSheet, gameData.entities[i].data.(EnemyData).deathAnimation.frames[gameData.entities[i].data.(EnemyData).deathAnimation.currentFrame], spritePosition, { 0, 0 }, 0.0, rl.WHITE);
                        }
                        
                    case .PROJECTILE:
                        rl.DrawTexturePro(assets.spriteSheet, gameData.entities[i].baseSprite, spritePosition, { 0, 0 }, 0.0, rl.WHITE)
                }
                
            }
            for i := 0; i < MAX_STARS; i += 1
            {
                rl.DrawPixelV(gameData.stars[i].position, rl.WHITE)
            }
        case .GAME_OVER:
            rl.EndTextureMode()
            if rl.IsSoundPlaying(assets.battleTheme) do rl.StopSound(assets.battleTheme)
            rl.PlaySound(assets.gameOver)
            rl.BeginDrawing()
            rl.DrawText("GAME OVER", GAME_WIDTH * GAME_SCALE_FACTOR / 2 - rl.MeasureText("GAME OVER", 60) / 2, GAME_HEIGHT * GAME_SCALE_FACTOR / 2 - 30, 60, rl.WHITE)
            rl.EndDrawing()
            rl.WaitTime(5.0)
            InitializeGameData(gameData)
            return
    }

    rl.EndTextureMode()


    rl.BeginDrawing()
    rl.ClearBackground(rl.BLACK)
    rl.DrawTexturePro(target.texture, 
    {0, 0, GAME_WIDTH, -GAME_HEIGHT},
    {0, 0, GAME_WIDTH * GAME_SCALE_FACTOR, GAME_HEIGHT * GAME_SCALE_FACTOR},
    {0, 0},
    0.0,
    rl.WHITE,
    )
    rl.EndDrawing()
}

KillEntity :: proc(gameData: ^GameData, id: u8)
{
    gameData.entities[id] = gameData.entities[gameData.entityCount - 1]
    gameData.entities[id].id = id
    gameData.entityCount -= 1
}

ShootProjectile :: proc(gameData: ^GameData, shooter: ^Entity, assets: ^Assets)
{
    velocity : rl.Vector2 = {0, 0}
    spawnPos : rl.Vector2 = {shooter.position.x, shooter.position.y}
    type : ProjectileType

    if shooter.type == .PLAYER && shooter.data.(PlayerData).currentProjectiles < gameData.maxPlayerProjectiles
    {
        velocity = {0, PLAYER_PROJECTILE_SPEED}
        type = .PLAYER_BULLET
        playerData := &shooter.data.(PlayerData)
        playerData.currentProjectiles += 1
        rl.PlaySound(assets.playerShoot);
    }
    else if shooter.type == .ENEMY
    {
        velocity = {0, 2.0}
        type = .ENEMY_BULLET
    }
    else do return
    spawnPos += PROJECTILE_OFFSET * velocity

    gameData.entities[gameData.entityCount] = {type = .PROJECTILE, position = spawnPos, velocity = velocity, size = 2, id = gameData.entityCount, baseSprite = BASE_BULLET_SPRITE}
    gameData.entities[gameData.entityCount].data = ProjectileData{ projectileType = type, ownerID = shooter.id }
    gameData.entityCount += 1
}

CheckCollision :: proc(entityA: Entity, entityB: Entity) -> bool
{
    return rl.CheckCollisionCircles(entityA.position, entityA.size * SPRITE_TO_HITBOX_SCALE, entityB.position, entityB.size * SPRITE_TO_HITBOX_SCALE)
}

main :: proc() 
{
    rl.InitWindow(GAME_WIDTH * GAME_SCALE_FACTOR, GAME_HEIGHT * GAME_SCALE_FACTOR, "Galaxian Clone")
    rl.InitAudioDevice()
    rl.SetTargetFPS(60)

    target : rl.RenderTexture2D = rl.LoadRenderTexture(GAME_WIDTH, GAME_HEIGHT)
    rl.SetTextureFilter(target.texture, rl.TextureFilter.POINT)

    gameData := new(GameData)
    InitializeGameData(gameData);

    assets := new(Assets)
    loadAssets(assets);

    currentTick : u32 = ENEMY_TICKS_PER_DIRECTION / 2
    lastTick := rl.GetTime()

    for !rl.WindowShouldClose()
    {
        HandleInput(gameData, assets)
        if (gameData.gameState == .IN_GAME)
        {
            if (rl.GetTime() - lastTick >= TICK_DURATION)
            {
				currentTick += 1;
				lastTick = rl.GetTime();
				Update(gameData, currentTick, assets);
            }
        }
        Draw(target, gameData, assets)
    }

    rl.CloseWindow()
}