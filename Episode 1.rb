#==========================================================================
# â— [VX] â—¦ Neo Save System V â—¦ â–¡
#---------------------------------------------------------------------------
# â—¦ Author: Woratana [woratana@hotmail.com], Zangther, Grim
# â—¦ Thaiware RPG Maker Community
#     http://rpg-maker-vx.bbactif.com/ and http://funkywork.blogspot.com
# â—¦ Last Updated:
# â—¦ Version: BBActif

#---------------------------------------------------------------------------
# â—¦ Log 1:
# No DLL required (New Version)
#===========================================================================

#==============================================================================
# ** Wora_NSS
#------------------------------------------------------------------------------
#  Configruation
#==============================================================================

module Wora_NSS
  #==========================================================================
  # * START NEO SAVE SYSTEM - SETUP
  #--------------------------------------------------------------------------
  OPACITY_DEFAULT = true # This will use the default opacity for windows
                   # Please note that this will affect both opacitys below
  NSS_WINDOW_OPACITY = 255 # All windows' opacity (Lowest 0 - 255 Highest)
  
  # If this is true then the scene will not change when you save the game
  SCENE_CHANGE = true  # Changes Scene to map if true

  MAX_SAVE_SLOT = 20 # Max save slots
  SLOT_NAME = 'SLOT {id}'
  # Name of the slot (show in save slots list), use {id} for slot ID
  SAVE_FILE_NAME = 'Save {id}.rvdata'
  # Save file name, you can also change its file type from .rvdata to other
 
  # Use {id} for save slot ID
  SAVE_PATH = '' # Path to store save file, e.g. 'Save/' or '' (for game folder)
  SAVED_SLOT_ICON = 133 # Icon Index for saved slot
 
  EMPTY_SLOT_ICON = 141 # Icon Index for empty slot
  EMPTY_SLOT_TEXT = 'Vide' # Text to show for empty slot's data
 
  DRAW_GOLD = true # Draw Gold
  DRAW_PLAYTIME = true # Draw Playtime
  DRAW_LOCATION = true # Draw location
  DRAW_FACE = true # Draw Actor's face
  DRAW_LEVEL = true # Draw Actor's level
  DRAW_NAME = true # Draw Actor's name
  DRAW_TEXT_GOLD = false # Draw the vocab::Gold text to the right of the number
 
  PLAYTIME_TEXT = 'Temps de jeu: '
  GOLD_TEXT = '            '
  LOCATION_TEXT = 'Localisation: '
  LV_TEXT = 'Lv. '
 
  MAP_NAME_TEXT_SUB = %w{}
  # Text that you want to remove from map name,
  # e.g. %w{[LN] [DA]} will remove text '[LN]' and '[DA]' from map name
  MAP_NO_NAME_LIST = [2] # ID of Map that will not show map name, e.g. [1,2,3]
  MAP_NO_NAME = '???' # What you will use to call the map in the no name list

  # This is a switch that can activate or deactivate maps from being displayed as
  # MAP_NO_NAME. If it is off then maps will return back to normal.
  MAP_NO_NAME_SWITCH = 95 # This switch has to be on for MAP_NO_NAME_LIST to work
 
  MAP_BORDER = Color.new(0,0,0,200) # Map image border color (R,G,B,Opacity)
  FACE_BORDER = Color.new(0,0,0,200) # Face border color
 
  # Save confirmation window
  SFC_Text_Confirm = 'Confirmer' # Text to confirm to save file
  SFC_Text_Cancel = 'Annuler' # Text to cancel to save
  SFC_Window_Width = 200 # Width of Confirmation Window
  SFC_Window_X_Offset = 0 # Move Confirmation Window horizontally
  SFC_Window_Y_Offset = 0 # Move Confirmation Window vertically
 
  #-------------------------------------------------------------------------
  # END NEO SAVE SYSTEM - SETUP (Edit below at your own risk)
  #=========================================================================
 
end

#==============================================================================
# ** Scene_File
#------------------------------------------------------------------------------
#  This class performs common processing for the save screen and load screen.
#==============================================================================

class Scene_File
  #-------------------------------------------------------------------------
  # * Dependancy
  #-------------------------------------------------------------------------
  include Wora_NSS
  #-------------------------------------------------------------------------
  # * Public instance variable
  #-------------------------------------------------------------------------
  attr_reader :window_slotdetail
  #-------------------------------------------------------------------------
  # * Alias
  #-------------------------------------------------------------------------
  alias old_write_save_data write_save_data
  #-------------------------------------------------------------------------
  # * Start processing
  #-------------------------------------------------------------------------
  def start
    super
    create_menu_background
    @help_window = Window_Help.new
    command = []
    (1..MAX_SAVE_SLOT).each do |i|
      command << SLOT_NAME.clone.gsub!(/\{ID\}/i) { i.to_s }
    end
    @window_slotdetail = Window_NSS_SlotDetail.new
    @window_slotlist = Window_SlotList.new(160, command)
    @window_slotlist.y = @help_window.height
    @window_slotlist.height = Graphics.height - @help_window.height
    unless OPACITY_DEFAULT
      @help_window.opacity = NSS_WINDOW_OPACITY
      @window_slotdetail.opacity = @window_slotlist.opacity = NSS_WINDOW_OPACITY
    end

    # Create Folder for Save file
    if SAVE_PATH != ''
      Dir.mkdir(SAVE_PATH) if !FileTest.directory?(SAVE_PATH)
    end
    if @saving
      @index = $game_temp.last_file_index
      @help_window.set_text(Vocab::SaveMessage)
    else
      @index = self.latest_file_index
      @help_window.set_text(Vocab::LoadMessage)
      (1..MAX_SAVE_SLOT).each do |i|
        @window_slotlist.draw_item(i-1, false) if !@window_slotdetail.file_exist?(i)
      end
    end
    @window_slotlist.index = @index
    # Draw Information
    @last_slot_index = @window_slotlist.index
    @window_slotdetail.draw_data(@last_slot_index + 1)
  end
  #-------------------------------------------------------------------------- 
  # * Termination Processing
  #--------------------------------------------------------------------------
  def terminate
    super
    dispose_menu_background
    if @bg
      @bg.bitmap.dispose
      @bg.dispose
    end
    @window_slotlist.dispose
    @window_slotdetail.dispose
    @help_window.dispose
  end
  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
  def update
    super
    if @confirm_window
      @confirm_window.update
      if Input.trigger?(Input::C)
        if @confirm_window.index == 0
          determine_savefile
          @confirm_window.dispose
          @confirm_window = nil
        else
          Sound.play_cancel
          @confirm_window.dispose
          @confirm_window = nil
        end
      elsif Input.trigger?(Input::B)
      Sound.play_cancel
      @confirm_window.dispose
      @confirm_window = nil
      end
    else
      update_menu_background
      @window_slotlist.update
      if @window_slotlist.index != @last_slot_index
        @last_slot_index = @window_slotlist.index
        @window_slotdetail.draw_data(@last_slot_index + 1)
      end
      @help_window.update
      update_savefile_selection
    end
  end
  #--------------------------------------------------------------------------
  # * Update Save File Selection
  #--------------------------------------------------------------------------
  def update_savefile_selection
    if Input.trigger?(Input::C)
      if @saving and @window_slotdetail.file_exist?(@last_slot_index + 1)
        Sound.play_decision
        text1 = SFC_Text_Confirm
        text2 = SFC_Text_Cancel
        @confirm_window = Window_Command.new(SFC_Window_Width,[text1,text2])
        @confirm_window.x = ((544 - @confirm_window.width) / 2) + SFC_Window_X_Offset
        @confirm_window.y = ((416 - @confirm_window.height) / 2) + SFC_Window_Y_Offset
      else
        determine_savefile
      end
    elsif Input.trigger?(Input::B)
      Sound.play_cancel
      return_scene
    end
  end
 
  #--------------------------------------------------------------------------
  # * Execute Save
  #--------------------------------------------------------------------------
  def do_save
    file = File.open(make_filename(@last_slot_index), "wb")
    write_save_data(file)
    file.close   
    if SCENE_CHANGE
      $scene = Scene_Map.new
    else
      $scene = Scene_File.new(true, false, false)
    end
  end
  #--------------------------------------------------------------------------
  # * Execute Load
  #--------------------------------------------------------------------------
  def do_load
    file = File.open(make_filename(@last_slot_index), "rb")
    read_save_data(file)
    file.close
    $scene = Scene_Map.new
    RPG::BGM.fade(1500)
    Graphics.fadeout(60)
    Graphics.wait(40)
    @last_bgm.play
    @last_bgs.play
  end
  #--------------------------------------------------------------------------
  # * Confirm Save File
  #--------------------------------------------------------------------------
  def determine_savefile
    if @saving
      Sound.play_save
      do_save
    else
      if @window_slotdetail.file_exist?(@last_slot_index + 1)
        Sound.play_load
        do_load
      else
        Sound.play_buzzer
        return
      end
    end
    $game_temp.last_file_index = @last_slot_index
  end
  #--------------------------------------------------------------------------
  # * Create Filename
  #    file_index : save file index (0-3)
  #--------------------------------------------------------------------------
  def make_filename(file_index)
    return SAVE_PATH + SAVE_FILE_NAME.gsub(/\{ID\}/i) { (file_index + 1).to_s }
  end
  #--------------------------------------------------------------------------
  # * Select File With Newest Timestamp
  #--------------------------------------------------------------------------
  def latest_file_index
    latest_index = 0
    latest_time = Time.at(0)
    (1..MAX_SAVE_SLOT).each do |i|
      file_name = make_filename(i - 1)
      next if !@window_slotdetail.file_exist?(i)
      file_time = File.mtime(file_name)
      if file_time > latest_time
        latest_time = file_time
        latest_index = i - 1
      end
    end
    return latest_index
  end
  #--------------------------------------------------------------------------
  # * Write Save Data
  #     file : write file object (opened)
  #--------------------------------------------------------------------------
  def write_save_data(file)
    old_write_save_data(file)
    Marshal.dump($game_temp.screenshot,         file)
  end
end


#==============================================================================
# ** Window_SlotList
#------------------------------------------------------------------------------
#  Define a Save Slot List
#==============================================================================

class Window_SlotList < Window_Command
  #--------------------------------------------------------------------------
  # * Draw Item
  #--------------------------------------------------------------------------
  def draw_item(index, enabled = true)
   rect = item_rect(index)
   rect.x += 4
   rect.width -= 8
   icon_index = 0
   self.contents.clear_rect(rect)
   if $scene.window_slotdetail.file_exist?(index + 1)
     icon_index = Wora_NSS::SAVED_SLOT_ICON
   else
     icon_index = Wora_NSS::EMPTY_SLOT_ICON
   end
   if icon_index
     rect.x -= 4
     draw_icon(icon_index, rect.x, rect.y, enabled) # Draw Icon
     rect.x += 26
     rect.width -= 20
   end
   self.contents.clear_rect(rect)
   self.contents.font.color = normal_color
   self.contents.font.color.alpha = enabled ? 255 : 128
   self.contents.draw_text(rect, @commands[index])
  end
  #--------------------------------------------------------------------------
  # * Move Cursor Down
  #--------------------------------------------------------------------------
  def cursor_down(wrap = false)
   if @index < @item_max - 1 or wrap
     @index = (@index + 1) % @item_max
   end
  end
  #--------------------------------------------------------------------------
  # * Move Cursor up
  #--------------------------------------------------------------------------
  def cursor_up(wrap = false)
   if @index > 0 or wrap
     @index = (@index - 1 + @item_max) % @item_max
   end
  end
end

#==============================================================================
# ** Window_SlotList
#------------------------------------------------------------------------------
#  Define a Save Slot detail 
#==============================================================================

class Window_NSS_SlotDetail < Window_Base
  #-------------------------------------------------------------------------
  # * Dependancy
  #-------------------------------------------------------------------------
  include Wora_NSS
  #-------------------------------------------------------------------------
  # * Object initialisation
  #-------------------------------------------------------------------------
  def initialize
   super(160, 56, 384, 360)
   @data = []
   @exist_list = []
   @bitmap_list = {}
   @map_name = []
  end
  #-------------------------------------------------------------------------
  # * Draw data in a slot
  #-------------------------------------------------------------------------
  def draw_data(slot_id)
   contents.clear # 352, 328
   load_save_data(slot_id) unless @data[slot_id]
   if @exist_list[slot_id]
    save_data = @data[slot_id]
    # DRAW SCREENSHOT
    contents.fill_rect(0,30,352,160, MAP_BORDER)
    bitmap = @data[slot_id]['screenshot']
    rect = Rect.new((Graphics.width-348)/2,(Graphics.height-156)/2,348,156)
    contents.blt(2,32,bitmap,rect)
     if DRAW_GOLD
      # DRAW GOLD
      gold_textsize = contents.text_size(save_data['gamepar'].gold).width
      goldt_textsize = contents.text_size(GOLD_TEXT).width 
      contents.font.color = system_color
      contents.draw_text(0, 0, goldt_textsize, WLH, GOLD_TEXT)
      contents.font.color = normal_color
      contents.draw_text(goldt_textsize, 0, gold_textsize, WLH, save_data['gamepar'].gold) 
      unless DRAW_TEXT_GOLD
        gold_textsize = 0
        goldt_textsize = 0   
      else
        contents.draw_text(goldt_textsize + gold_textsize, 0, 200, WLH, Vocab::gold)
      end
     end
     if DRAW_PLAYTIME
      # DRAW PLAYTIME
      hour = save_data['total_sec'] / 60 / 60
      min = save_data['total_sec'] / 60 % 60
      sec = save_data['total_sec'] % 60
      time_string = sprintf("%02d:%02d:%02d", hour, min, sec)
      pt_textsize = contents.text_size(PLAYTIME_TEXT).width
      ts_textsize = contents.text_size(time_string).width
      contents.font.color = system_color
      contents.draw_text(contents.width - ts_textsize - pt_textsize, 0,
      pt_textsize, WLH, PLAYTIME_TEXT)
      contents.draw_text(goldt_textsize + gold_textsize,0,200,WLH, Vocab::gold)
      contents.font.color = normal_color
      contents.draw_text(0, 0, contents.width, WLH, time_string, 2)
     end
     if DRAW_LOCATION
      # DRAW LOCATION
      lc_textsize = contents.text_size(LOCATION_TEXT).width
      mn_textsize = contents.text_size(save_data['map_name']).width
      contents.font.color = system_color
      contents.draw_text(0, 190, contents.width, WLH, LOCATION_TEXT)
      contents.font.color = normal_color
      contents.draw_text(lc_textsize, 190, contents.width, WLH, save_data['map_name'])
     end
      # DRAW FACE & Level & Name
      save_data['gamepar'].members.each_index do |i|
        actor = save_data['gameactor'][save_data['gamepar'].members[i].id]
        face_x_base = (i*80) + (i*8)
        face_y_base = 216
        lvn_y_plus = 10
        lv_textsize = contents.text_size(actor.level).width
        lvt_textsize = contents.text_size(LV_TEXT).width
      if DRAW_FACE
        # Draw Face
        contents.fill_rect(face_x_base, face_y_base, 84, 84, FACE_BORDER)
        draw_face(actor.face_name, actor.face_index, face_x_base + 2,
        face_y_base + 2, 80)
      end
      if DRAW_LEVEL
        # Draw Level
        contents.font.color = system_color
        contents.draw_text(face_x_base + 2 + 80 - lv_textsize - lvt_textsize,
        face_y_base + 2 + 80 - WLH + lvn_y_plus, lvt_textsize, WLH, LV_TEXT)
        contents.font.color = normal_color
        contents.draw_text(face_x_base + 2 + 80 - lv_textsize,
        face_y_base + 2 + 80 - WLH + lvn_y_plus, lv_textsize, WLH, actor.level)
      end
      if DRAW_NAME
        # Draw Name
        contents.draw_text(face_x_base, face_y_base + 2 + 80 + lvn_y_plus - 6, 84,
        WLH, actor.name, 1)
      end
     end
   else
     contents.draw_text(0,0, contents.width, contents.height - WLH, EMPTY_SLOT_TEXT, 1)
   end
  end
  #-------------------------------------------------------------------------
  # * Load data on a slot
  #-------------------------------------------------------------------------
  def load_save_data(slot_id)
   file_name = make_filename(slot_id)
   if file_exist?(slot_id) or FileTest.exist?(file_name)
     @exist_list[slot_id] = true
     @data[slot_id] = {}
     # Start load data
     file = File.open(file_name, "r")
     @data[slot_id]['time'] = file.mtime
     @data[slot_id]['char'] = Marshal.load(file)
     @data[slot_id]['frame'] = Marshal.load(file)
     @data[slot_id]['last_bgm'] = Marshal.load(file)
     @data[slot_id]['last_bgs'] = Marshal.load(file)
     @data[slot_id]['gamesys'] = Marshal.load(file)
     @data[slot_id]['gamemes'] = Marshal.load(file)
     @data[slot_id]['gameswi'] = Marshal.load(file)
     @data[slot_id]['gamevar'] = Marshal.load(file)
     @data[slot_id]['gameselfvar'] = Marshal.load(file)
     @data[slot_id]['gameactor'] = Marshal.load(file)
     @data[slot_id]['gamepar'] = Marshal.load(file)
     @data[slot_id]['gametro'] = Marshal.load(file)
     @data[slot_id]['gamemap'] = Marshal.load(file)
     @data[slot_id]['player'] = Marshal.load(file)
     @data[slot_id]['screenshot'] = Marshal.load(file)
     @data[slot_id]['total_sec'] = @data[slot_id]['frame'] / Graphics.frame_rate
     @data[slot_id]['map_name'] = get_mapname(@data[slot_id]['gamemap'].map_id)
     file.close
   else
     @exist_list[slot_id] = false
     @data[slot_id] = -1
   end
  end
  #-------------------------------------------------------------------------
  # * Define a file name
  #-------------------------------------------------------------------------
  def make_filename(file_index)
   return SAVE_PATH + SAVE_FILE_NAME.gsub(/\{ID\}/i) { (file_index).to_s }
  end
  #-------------------------------------------------------------------------
  # * Check file existence
  #-------------------------------------------------------------------------
  def file_exist?(slot_id)
    @exist_list[slot_id] ||= FileTest.exist?(make_filename(slot_id))
   return @exist_list[slot_id]
  end
  #-------------------------------------------------------------------------
  # * Get the Map name
  #-------------------------------------------------------------------------
  def get_mapname(map_id)
    unless @map_data
      @map_data = load_data("Data/MapInfos.rvdata")
    end
    unless @map_name[map_id]
      if MAP_NO_NAME_LIST.include?(map_id) and $game_switches[MAP_NO_NAME_SWITCH]
        @map_name[map_id] = MAP_NO_NAME
      else
        @map_name[map_id] = @map_data[map_id].name
      end 
      MAP_NAME_TEXT_SUB.each_index do |i|
        @map_name[map_id].sub!(MAP_NAME_TEXT_SUB[i], '')
        @mapname = @map_name[map_id]
      end
    end
    return @map_name[map_id]
  end
 
end

#==============================================================================
# ** Scene_Title
#------------------------------------------------------------------------------
#  This class performs the title screen processing.
#==============================================================================

class Scene_Title
  #-------------------------------------------------------------------------
  # * Check "continue" state
  #-------------------------------------------------------------------------
  def check_continue
   file_name = Wora_NSS::SAVE_PATH + Wora_NSS::SAVE_FILE_NAME.gsub(/\{ID\}/i) { '*' }
   @continue_enabled = (Dir.glob(file_name).size > 0)
  end
end

#==============================================================================
# ** Marshal implementations in Font & Bitmap.
#------------------------------------------------------------------------------
#  Writed by Yeyinde
#  Improved by Grim (FunkyWork)
#==============================================================================
class Font
  def marshal_dump;end
  def marshal_load(obj);end
end
  
class Bitmap
  #--------------------------------------------------------------------------
  # * Win32API
  #--------------------------------------------------------------------------
  @@RtlMoveMemorySave = Win32API.new('kernel32','RtlMoveMemory','pii','i')
  @@RtlMoveMemoryLoad = Win32API.new('kernel32','RtlMoveMemory','ipi','i')
  #--------------------------------------------------------------------------
  # * Marshall dump
  #--------------------------------------------------------------------------
  def _dump(limit)
    data = "rgba"*width*height
    @@RtlMoveMemorySave.call(data,address,data.length)
    [width,height,Zlib::Deflate.deflate(data)].pack("LLa*")
  end

  #--------------------------------------------------------------------------
  # * Marshall load
  #--------------------------------------------------------------------------
  def self._load(str)
    w,h,zdata = str.unpack("LLa*")
    bitmap = new(w,h)
    @@RtlMoveMemoryLoad.call(bitmap.address,Zlib::Inflate.inflate(zdata),w*h*4)
    return bitmap
  end

  #--------------------------------------------------------------------------
  # * Récupère l'adresse
  #--------------------------------------------------------------------------
  def address
    buffer,ad="xxxx",object_id*2+16
    @@RtlMoveMemorySave.call(buffer,ad,4)
    ad=buffer.unpack("L")[0]+8
    @@RtlMoveMemorySave.call(buffer,ad,4)
    ad=buffer.unpack("L")[0]+16
    @@RtlMoveMemorySave.call(buffer,ad,4)
    return buffer.unpack("L")[0]
  end
end

#==============================================================================
# ** Scene_Map
#------------------------------------------------------------------------------
#  Added, make snapshot in pre_terminate
#==============================================================================
class Scene_Map
  #--------------------------------------------------------------------------
  # * Alias
  #--------------------------------------------------------------------------
  alias old_pre_terminate pre_terminate
  #--------------------------------------------------------------------------
  # * Pre-termination Processing
  #--------------------------------------------------------------------------
  def pre_terminate
    old_pre_terminate
    make_snapshot
  end
end

#==============================================================================
# ** Scene_Base
#------------------------------------------------------------------------------
#  Added, make snapshot
#==============================================================================
class Scene_Base
  #--------------------------------------------------------------------------
  # * Pre-termination Processing
  #--------------------------------------------------------------------------
  def make_snapshot
    $game_temp.screenshot = Graphics.snap_to_bitmap
  end
end

#==============================================================================
# ** Game_Temp
#------------------------------------------------------------------------------
#  This class handles temporary data that is not included with save data.
# The instance of this class is referenced by $game_temp.
#==============================================================================
class Game_Temp
  #--------------------------------------------------------------------------
  # * Alias
  #--------------------------------------------------------------------------
  alias old_initialize initialize
  #--------------------------------------------------------------------------
  # * Public Instance Variables
  #--------------------------------------------------------------------------
  attr_accessor :screenshot        # background bitmap
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize
    old_initialize
    @screenshot = Bitmap.new(1,1)
  end
end
