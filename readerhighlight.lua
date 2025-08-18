local ReaderHighlight = require("apps/reader/modules/readerhighlight")

local logger = require("logger")

function ReaderHighlight:updateHighlightPaging(highlight, side, direction)
    logger.dbg("ReaderHighlight:updateHighlightPaging", highlight)
    local page = highlight.page
    local pboxes
    if highlight.ext then -- multipage highlight, don't move invisible boundaries
        if
            (page ~= highlight.pos0.page and page ~= highlight.pos1.page) -- middle pages
            or (page == highlight.pos0.page and side == 1) -- first page, tried to move end
            or (page == highlight.pos1.page and side == 0)
        then -- last page, tried to move start
            return
        end
        pboxes = highlight.ext[page].pboxes
    else
        pboxes = highlight.pboxes
    end
    local page_boxes = self.document:getTextBoxes(page)

    -- find page boxes indices of the highlight start and end pboxes
    -- pboxes { x, y, h, w }; page_boxes { x0, y0, x1, y1, word }
    local start_i, start_j, end_i, end_j
    local function is_equal(a, b)
        return math.abs(a - b) < 0.001
    end
    local start_box = pboxes[1]
    local end_box = pboxes[#pboxes]
    for i, line in ipairs(page_boxes) do
        for j, box in ipairs(line) do
            if not start_i and is_equal(start_box.x, box.x0) and is_equal(start_box.y, box.y0) then
                start_i, start_j = i, j
            end
            if not end_i and is_equal(end_box.x + end_box.w, box.x1) and is_equal(end_box.y, box.y0) then
                end_i, end_j = i, j
            end
            if start_i and end_i then
                break
            end
        end
        if start_i and end_i then
            break
        end
    end
    if not (start_i and end_i) then
        return
    end

    -- move
    local new_start_i, new_start_j, new_end_i, new_end_j
    if side == 0 then -- we move pos0
        new_end_i, new_end_j = end_i, end_j
        if direction == 1 then -- move highlight to the right
            if start_i == end_i and start_j == end_j then
                return
            end -- don't move start behind end
            if start_j == #page_boxes[start_i] then -- last box of the line
                new_start_i = start_i + 1
                new_start_j = 1
                table.remove(pboxes, 1)
            else
                new_start_i = start_i
                new_start_j = start_j + 1
                pboxes[1].x = page_boxes[new_start_i][new_start_j].x0
                local last_box_j = new_start_i == new_end_i and new_end_j or #page_boxes[new_start_i]
                local last_box = page_boxes[new_start_i][last_box_j] -- last highlighted box of the line
                pboxes[1].w = last_box.x1 - pboxes[1].x
            end
            local removed_word = page_boxes[start_i][start_j].word
            if removed_word then
                highlight.text = highlight.text:sub(#removed_word + 2) -- remove first word and space after it
            end
        else -- move highlight to the left
            local new_box
            if start_j == 1 then -- first box of the line
                if start_i == 1 then
                    return
                end -- first line of the page, don't move to the previous page
                new_start_i = start_i - 1
                new_start_j = #page_boxes[new_start_i]
                new_box = page_boxes[new_start_i][new_start_j]
                table.insert(
                    pboxes,
                    1,
                    { x = new_box.x0, y = new_box.y0, w = new_box.x1 - new_box.x0, h = new_box.y1 - new_box.y0 }
                )
            else
                new_start_i = start_i
                new_start_j = start_j - 1
                new_box = page_boxes[new_start_i][new_start_j]
                pboxes[1].x = new_box.x0
                local last_box_j = new_start_i == new_end_i and new_end_j or #page_boxes[new_start_i]
                local last_box = page_boxes[new_start_i][last_box_j] -- last highlighted box of the line
                pboxes[1].w = last_box.x1 - pboxes[1].x
            end
            if new_box.word then
                highlight.text = new_box.word .. " " .. highlight.text
            end
        end
    else -- we move pos1
        new_start_i, new_start_j = start_i, start_j
        if direction == 1 then -- move highlight to the right
            local new_box
            if end_j == #page_boxes[end_i] then -- last box of the line
                if end_i == #page_boxes then
                    return
                end -- last line of the page, don't move to the next page
                new_end_i = end_i + 1
                new_end_j = 1
                new_box = page_boxes[new_end_i][new_end_j]
                table.insert(
                    pboxes,
                    { x = new_box.x0, y = new_box.y0, w = new_box.x1 - new_box.x0, h = new_box.y1 - new_box.y0 }
                )
            else
                new_end_i = end_i
                new_end_j = end_j + 1
                new_box = page_boxes[new_end_i][new_end_j]
                pboxes[#pboxes].w = new_box.x1 - pboxes[#pboxes].x
            end
            if new_box.word then
                highlight.text = highlight.text .. " " .. new_box.word
            end
        else -- move highlight to the left
            if start_i == end_i and start_j == end_j then
                return
            end -- don't move end before start
            if end_j == 1 then -- first box of the line
                new_end_i = end_i - 1
                new_end_j = #page_boxes[new_end_i]
                table.remove(pboxes)
            else
                new_end_i = end_i
                new_end_j = end_j - 1
                local last_box = page_boxes[new_end_i][new_end_j] -- last highlighted box of the line
                pboxes[#pboxes].w = last_box.x1 - pboxes[#pboxes].x
            end
            local removed_word = page_boxes[end_i][end_j].word
            if removed_word then
                highlight.text = highlight.text:sub(1, -(#removed_word + 2)) -- remove last word and space before it
            end
        end
    end
    start_box, end_box = page_boxes[new_start_i][new_start_j], page_boxes[new_end_i][new_end_j]
    if highlight.ext then -- multipage highlight
        if side == 0 then -- we move pos0
            highlight.pos0.x = (start_box.x0 + start_box.x1) / 2
            highlight.pos0.y = (start_box.y0 + start_box.y1) / 2
            highlight.ext[page].pos0.x = highlight.pos0.x
            highlight.ext[page].pos0.y = highlight.pos0.y
        else
            highlight.pos1.x = (end_box.x0 + end_box.x1) / 2
            highlight.pos1.y = (end_box.y0 + end_box.y1) / 2
            highlight.ext[page].pos1.x = highlight.pos1.x
            highlight.ext[page].pos1.y = highlight.pos1.y
        end
    else
        -- pos0 and pos1 may be not in order, reassign all
        highlight.pos0.x = (start_box.x0 + start_box.x1) / 2
        highlight.pos0.y = (start_box.y0 + start_box.y1) / 2
        highlight.pos1.x = (end_box.x0 + end_box.x1) / 2
        highlight.pos1.y = (end_box.y0 + end_box.y1) / 2
    end
    return true
end

return ReaderHighlight
