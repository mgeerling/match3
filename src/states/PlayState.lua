--[[
    GD50
    Match-3 Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    State in which we can actually play, moving around a grid cursor that
    can swap two tiles; when two tiles make a legal swap (a swap that results
    in a valid match), perform the swap and destroy all matched tiles, adding
    their values to the player's point score. The player can continue playing
    until they exceed the number of points needed to get to the next level
    or until the time runs out, at which point they are brought back to the
    main menu or the score entry menu if they made the top 10.
]]

PlayState = Class{__includes = BaseState}

function PlayState:init()
    
    -- start our transition alpha at full, so we fade in
    self.transitionAlpha = 1

    -- position in the grid which we're highlighting
    self.boardHighlightX = 0
    self.boardHighlightY = 0

    -- timer used to switch the highlight rect's color
    self.rectHighlighted = false

    -- flag to show whether we're able to process input (not swapping or clearing)
    self.canInput = true

    -- tile we're currently highlighting (preparing to swap)
    self.highlightedTile = nil

    self.score = 0
    self.timer = 60

    -- set our Timer class to turn cursor highlight on and off
    Timer.every(0.5, function()
        self.rectHighlighted = not self.rectHighlighted
    end)

    -- subtract 1 from timer every second
    Timer.every(1, function()
        self.timer = self.timer - 1

        -- play warning sound on timer if we get low
        if self.timer <= 5 then
            gSounds['clock']:play()
        end
    end)
end

function PlayState:enter(params)
    
    -- grab level # from the params we're passed
    self.level = params.level

    --TODO when, if ever is the Board called? 
    -- spawn a board and place it toward the right
    self.board = params.board or Board(VIRTUAL_WIDTH - 272, 16, 2)

    -- grab score from params if it was passed
    self.score = params.score or 0

    -- score we have to reach to get to the next level
    self.scoreGoal = self.level * 1.25 * 1000

    -- self:possibleMatches()

end

function PlayState:update(dt)
    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end

    -- go back to start if time runs out
    if self.timer <= 0 then
        
        -- clear timers from prior PlayStates
        Timer.clear()
        
        gSounds['game-over']:play()

        gStateMachine:change('game-over', {
            score = self.score
        })
    end

    -- go to next level if we surpass score goal
    if self.score >= self.scoreGoal then
        
        -- clear timers from prior PlayStates
        -- always clear before you change state, else next state's timers
        -- will also clear!
        Timer.clear()

        gSounds['next-level']:play()

        -- change to begin game state with new level (incremented)
        gStateMachine:change('begin-game', {
            level = self.level + 1,
            score = self.score
        })
    end

    if self.canInput then
        -- move cursor around based on bounds of grid, playing sounds
        if love.keyboard.wasPressed('up') then
            self.boardHighlightY = math.max(0, self.boardHighlightY - 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('down') then
            self.boardHighlightY = math.min(7, self.boardHighlightY + 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('left') then
            self.boardHighlightX = math.max(0, self.boardHighlightX - 1)
            gSounds['select']:play()
        elseif love.keyboard.wasPressed('right') then
            self.boardHighlightX = math.min(7, self.boardHighlightX + 1)
            gSounds['select']:play()
        end

        -- if we've pressed enter, to select or deselect a tile...
        if love.keyboard.wasPressed('enter') or love.keyboard.wasPressed('return') then
            
            -- if same tile as currently highlighted, deselect
            local x = self.boardHighlightX + 1
            local y = self.boardHighlightY + 1
            
            -- if nothing is highlighted, highlight current tile
            if not self.highlightedTile then
                self.highlightedTile = self.board.tiles[y][x]

            -- if we select the position already highlighted, remove highlight
            elseif self.highlightedTile == self.board.tiles[y][x] then
                self.highlightedTile = nil

            -- if the difference between X and Y combined of this highlighted tile
            -- vs the previous is not equal to 1, also remove highlight
            elseif math.abs(self.highlightedTile.gridX - x) + math.abs(self.highlightedTile.gridY - y) > 1 then
                gSounds['error']:play()
                self.highlightedTile = nil
            else

                --TODO call swap here 

                self:swapTiles(self.highlightedTile, self.board.tiles[y][x], true)
                self:possibleMatches()
                

                
                -- swap grid positions of tiles
                -- local tempX = self.highlightedTile.gridX
                -- local tempY = self.highlightedTile.gridY

                -- local newTile = self.board.tiles[y][x]

                -- self.highlightedTile.gridX = newTile.gridX
                -- self.highlightedTile.gridY = newTile.gridY
                -- newTile.gridX = tempX
                -- newTile.gridY = tempY

                -- -- swap tiles in the tiles table
                -- self.board.tiles[self.highlightedTile.gridY][self.highlightedTile.gridX] =
                --     self.highlightedTile

                -- self.board.tiles[newTile.gridY][newTile.gridX] = newTile

                -- tween coordinates between the two so they swap
            --     Timer.tween(0.1, {
            --         [self.highlightedTile] = {x = newTile.x, y = newTile.y},
            --         [newTile] = {x = self.highlightedTile.x, y = self.highlightedTile.y}
            --     })
                
            --     --once the swap is finished, we can tween falling blocks as needed
            --     :finish(function()
            --         self:calculateMatches()
            --         --Can I tween backwards in here?
            --     end)
            end
        end
    end

    Timer.update(dt)
end

--[[
    Calculates whether any matches were found on the board and tweens the needed
    tiles to their new destinations if so. Also removes tiles from the board that
    have matched and replaces them with new randomized tiles, deferring most of this
    to the Board class.
]]
function PlayState:calculateMatches(bool)
    self.highlightedTile = nil

    -- if we have any matches, remove them and tween the falling blocks that result
    local matches = self.board:calculateMatches()
    local wasMatch = bool
    
    if matches then
        gSounds['match']:stop()
        gSounds['match']:play()

        wasMatch = true 

        -- add score for each match
        -- mbg - adding time as well too 
        for k, match in pairs(matches) do
            self.score = self.score + #match * 50
            -- adds a second per tile in match since we are looking at total length of match 
            self.timer = self.timer + #match
        end

        -- remove any tiles that matched from the board, making empty spaces
        self.board:removeMatches()

        -- gets a table with tween values for tiles that should now fall
        local tilesToFall = self.board:getFallingTiles()

        -- tween new tiles that spawn from the ceiling over 0.25s to fill in
        -- the new upper gaps that exist
        Timer.tween(0.25, tilesToFall):finish(function()
            
            -- recursively call function in case new matches have been created
            -- as a result of falling blocks once new blocks have finished falling

            --I think this can be wasMatch -- TODO MBG
            self:calculateMatches(true)
        end)
    
    -- if no matches, we can continue playing
    else
        self.canInput = true
        return wasMatch
    end
end

function PlayState:render()
    -- render board of tiles
    self.board:render()

    -- render highlighted tile if it exists
    if self.highlightedTile then
        
        -- multiply so drawing white rect makes it brighter
        love.graphics.setBlendMode('add')

        love.graphics.setColor(1, 1, 1, 96/255)
        love.graphics.rectangle('fill', (self.highlightedTile.gridX - 1) * 32 + (VIRTUAL_WIDTH - 272),
            (self.highlightedTile.gridY - 1) * 32 + 16, 32, 32, 4)

        -- back to alpha
        love.graphics.setBlendMode('alpha')
    end

    -- render highlight rect color based on timer
    if self.rectHighlighted then
        love.graphics.setColor(217/255, 87/255, 99/255, 1)
    else
        love.graphics.setColor(172/255, 50/255, 50/255, 1)
    end

    -- draw actual cursor rect
    love.graphics.setLineWidth(4)
    love.graphics.rectangle('line', self.boardHighlightX * 32 + (VIRTUAL_WIDTH - 272),
        self.boardHighlightY * 32 + 16, 32, 32, 4)

    -- GUI text
    love.graphics.setColor(56/255, 56/255, 56/255, 234/255)
    love.graphics.rectangle('fill', 16, 16, 186, 116, 4)

    love.graphics.setColor(99/255, 155/255, 1, 1)
    love.graphics.setFont(gFonts['medium'])
    love.graphics.printf('Level: ' .. tostring(self.level), 20, 24, 182, 'center')
    love.graphics.printf('Score: ' .. tostring(self.score), 20, 52, 182, 'center')
    love.graphics.printf('Goal : ' .. tostring(self.scoreGoal), 20, 80, 182, 'center')
    love.graphics.printf('Timer: ' .. tostring(self.timer), 20, 108, 182, 'center')
end

function PlayState:swapTiles(tile1, tile2, type)

    local tempX = tile1.gridX
    local tempY = tile1.gridY

    local newTile = tile2
    local mode = type 
    local board = board

    tile1.gridX = newTile.gridX
    tile1.gridY = newTile.gridY
    newTile.gridX = tempX
    newTile.gridY = tempY

    -- swap tiles in the tiles table
    self.board.tiles[tile1.gridY][tile1.gridX] = tile1

    self.board.tiles[newTile.gridY][newTile.gridX] = newTile

    if mode == true then 

        -- tween coordinates between the two so they swap
        Timer.tween(0.1, {
            [tile1] = {x = newTile.x, y = newTile.y},
            [newTile] = {x = tile1.x, y = tile1.y}
        })
        --once the swap is finished, we can tween falling blocks as needed
        :finish(function()
            if mode == true then
                --TODO change 
                local validMove = self:calculateMatches(false) --need to get result here 
                --Can I tween backwards in here?
                if validMove == false then 
                    -- this was not a valid move 
                    --TODO Swap back 
                    --gSounds['game-over']:play()
                end 
            else 
                --TODO change board reference?
                local matches = self.board:calculateMatches()
                if matches then 
                    gSounds['game-over']:play()            
                end 
            end 
        end)
    end 

end 

function PlayState:possibleMatches()
    -- for x = 2, 7 do 
    --     Timer.after(x, function () self:swapTiles(self.board.tiles[2][x], self.board.tiles[2][x-1], true) end)
    --     Timer.after(x+1, function () self:swapTiles(self.board.tiles[2][x], self.board.tiles[2][x-1], true) end)
    -- end 
    -- Timer.after(1, function () self:swapTiles(self.board.tiles[2][2], self.board.tiles[2][2-1], false) end)
    -- Timer.after(2, function () self:swapTiles(self.board.tiles[2][2], self.board.tiles[2][2-1], false) end)
    -- Timer.after(3, function () self:swapTiles(self.board.tiles[2][3], self.board.tiles[2][3-1], false) end)
    -- Timer.after(4, function () self:swapTiles(self.board.tiles[2][3], self.board.tiles[2][3-1], false) end)
    -- Timer.after(5, function () self:swapTiles(self.board.tiles[2][4], self.board.tiles[2][4-1], false) end)
    -- Timer.after(6, function () self:swapTiles(self.board.tiles[2][4], self.board.tiles[2][4-1], false) end)

    --swap left 
    self:swapTiles(self.board.tiles[2][2], self.board.tiles[2][2-1], false)
    local matches = self.board:calculateMatches()
    if matches then 
        gSounds['game-over']:play()            
    end 
    self:swapTiles(self.board.tiles[2][2], self.board.tiles[2][2-1], false)

    -- swap right 
    self:swapTiles(self.board.tiles[2][2], self.board.tiles[2][2+1], false)
    local matches = self.board:calculateMatches()
    if matches then 
        gSounds['game-over']:play()            
    end 
    self:swapTiles(self.board.tiles[2][2], self.board.tiles[2][2+1], false)

    -- swap up 
    self:swapTiles(self.board.tiles[2][2], self.board.tiles[2-1][2], false)
    local matches = self.board:calculateMatches()
    if matches then 
        gSounds['game-over']:play()            
    end 
    self:swapTiles(self.board.tiles[2][2], self.board.tiles[2-1][2], false)

    -- swap down 
    self:swapTiles(self.board.tiles[2][2], self.board.tiles[2+1][2], false)
    local matches = self.board:calculateMatches()
    if matches then 
        gSounds['game-over']:play()            
    end 
    self:swapTiles(self.board.tiles[2][2], self.board.tiles[2+1][2], false)
    


    --create a new temp board 
    --local tempBoard = self.board

    -- for y = 1, 8 do
    --     for x = 1, 8 do 
    --         local tile = tempBoard.tiles[y][x]
    --         local tempX = tile.gridX
    --         local tempY = tile.gridY
    --         --switch left 
    --         local switchTile = tempBoard.tiles[y][x-1]
    --         --blah blah TODO 
    --     end 
    -- end 

    -- local tempX = tile1.gridX
    -- local tempY = tile1.gridY

    -- local newTile = tile2

    -- tile1.gridX = newTile.gridX
    -- tile1.gridY = newTile.gridY
    -- newTile.gridX = tempX
    -- newTile.gridY = tempY

    -- -- swap tiles in the tiles table
    -- self.board.tiles[tile1.gridY][tile1.gridX] =
    --     tile1

    -- self.board.tiles[newTile.gridY][newTile.gridX] = newTile

    -- for x = 2, 7 do 
    --     -- local tempX = self.highlightedTile.gridX
    --             -- local tempY = self.highlightedTile.gridY

    --             -- local newTile = self.board.tiles[y][x]

    --             -- self.highlightedTile.gridX = newTile.gridX
    --             -- self.highlightedTile.gridY = newTile.gridY
    --             -- newTile.gridX = tempX
    --             -- newTile.gridY = tempY

    --             -- -- swap tiles in the tiles table
    --             -- self.board.tiles[self.highlightedTile.gridY][self.highlightedTile.gridX] =
    --             --     self.highlightedTile

    --             -- self.board.tiles[newTile.gridY][newTile.gridX] = newTile

    --             -- tween coordinates between the two so they swap
    --             -- Timer.tween(0.1, {
    --             --     [self.highlightedTile] = {x = newTile.x, y = newTile.y},
    --             --     [newTile] = {x = self.highlightedTile.x, y = self.highlightedTile.y}
    --             -- })
    --     self:swapTiles(self.board.tiles[2][x], self.board.tiles[2][x-1], false)
    --     --self:swapTiles(self.board.tiles[2][x], self.board.tiles[2][x-1], false)

    -- end 



    -- swap grid positions of tiles
                -- local tempX = self.highlightedTile.gridX
                -- local tempY = self.highlightedTile.gridY

                -- local newTile = self.board.tiles[y][x]

                -- self.highlightedTile.gridX = newTile.gridX
                -- self.highlightedTile.gridY = newTile.gridY
                -- newTile.gridX = tempX
                -- newTile.gridY = tempY

                -- -- swap tiles in the tiles table
                -- self.board.tiles[self.highlightedTile.gridY][self.highlightedTile.gridX] =
                --     self.highlightedTile

                -- self.board.tiles[newTile.gridY][newTile.gridX] = newTile

                -- tween coordinates between the two so they swap
                -- Timer.tween(0.1, {
                --     [self.highlightedTile] = {x = newTile.x, y = newTile.y},
                --     [newTile] = {x = self.highlightedTile.x, y = self.highlightedTile.y}
                -- })




    -- start at first tile 
    --swap left, swap right, swap up, swap down
    --local matches = self.board:calculateMatches()
end 