

dir_utilities = {}


-- Function that lists folders in the directory where the Lua script is located

function dir_utilities.listFolders(directory)
    
    local folders = {}

    -- List all files and folders in the current directory
    local files = fs.list(directory)


    for _, file in ipairs(files) do
        
        local path = directory .. "/" .. file
        -- Check if it is a directory
        if fs.isDir(path) then
            table.insert(folders, file)
        end
    end

    return folders
end

-- Show the found folders
--local folderList = listRelativeFolders()
--for _, folder in ipairs(folderList) do
--    print(folder)
--end

function dir_utilities.is_extension(path, extension)
    local ext = path:match("^.+(%..+)$")
    return ext and ext:lower() == extension:lower()  -- Comparación insensible a mayúsculas
end

function dir_utilities.listFiles(directory,extension)
    
    --print("DIR",directory)
    local only_files = {}

    -- List all files and folders in the current directory
    local files = fs.list(directory)


    for _, file in ipairs(files) do
        
        local path = directory .. "/" .. file
        -- Check if it is a directory
        
        if not fs.isDir(path) and (format==nil or dir_utilities.is_extension(path,extension)) then
            table.insert(only_files, path)
        end
    end


    return only_files
end



return dir_utilities