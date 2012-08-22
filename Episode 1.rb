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
  NSS_WINDOW_OPACITY = 255 # All windows' opacity (Lowest 0 - 255 Highest)

  # If this is true then the scene will not change when you save the game
  SCENE_CHANGE = true  # Changes Scene to map if true

  MAX_SAVE_SLOT = 20 # Max save slots
  SLOT_NAME = 'SLOT {id}'
  # Name of the slot (show in save slots list), use {id} for slot ID
  SAVE_FILE_NAME = 'Save{id}.rvdata'
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

  PLAYTIME_TEXT = 'Temps de jeu: '  
  LOCATION_TEXT = 'Localisation: '
  LV_TEXT = 'Lv. '

  MAP_NAME_TEXT_SUB = %w{}
  # Text that you want to remove from map name,
  # e.g. %w{[LN] [DA]} will remove text '[LN]' and '[DA]' from map name
  MAP_NO_NAME_LIST = [] # ID of Map that will not show map name, e.g. [1,2,3]
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
    @data = {}
    create_windows
    # Create Folder for Save file if needed
    if Wora_NSS::SAVE_PATH != '' && !FileTest.directory?(Wora_NSS::SAVE_PATH)
      Dir.mkdir(Wora_NSS::SAVE_PATH)
    end
  end
  #-------------------------------------------------------------------------
  # * Create the windows
  #-------------------------------------------------------------------------
  def create_windows
    # Help Window
    @help_window = Window_Help.new
    @help_window.set_text(@saving ? Vocab::SaveMessage : Vocab::LoadMessage)
    @help_window.opacity = Wora_NSS::NSS_WINDOW_OPACITY
    # Detail Window
    @window_slotdetail = Window_NSS_SlotDetail.new(160, 56, 384, 360)
    # Slots Window
    commands = []
    1.upto(Wora_NSS::MAX_SAVE_SLOT) do |num|
      commands << Wora_NSS::SLOT_NAME.gsub(/\{ID\}/i) { num.to_s }
    end
    y = @help_window.height
    height = Graphics.height - y
    @window_slotlist = Window_SlotList.new(0, y, 160, height, commands) 
    @window_slotlist.commands.each_index do |index|
      file_exist = FileTest.exist?(make_filename(index + 1))
      if file_exist
        load_display_data(index + 1)
      else
        set_empty_state(index + 1)
        @window_slotlist.draw_item(index, file_exist)
      end
    end
    # Confirmation Window
    text1 = Wora_NSS::SFC_Text_Confirm
    text2 = Wora_NSS::SFC_Text_Cancel
    @confirm_window = Window_Command.new(Wora_NSS::SFC_Window_Width,[text1,text2])
    @confirm_window.x = ((544 - @confirm_window.width) / 2) + Wora_NSS::SFC_Window_X_Offset
    @confirm_window.y = ((416 - @confirm_window.height) / 2) + Wora_NSS::SFC_Window_Y_Offset
    @confirm_window.visible = @confirm_window.active = false
    # Starting with an non existant previous index 
    @index = -1 
  end
  #-------------------------------------------------------------------------- 
  # * Termination Processing
  #--------------------------------------------------------------------------
  def terminate
    super
    dispose_menu_background
    @window_slotlist.dispose
    @window_slotdetail.dispose
    @help_window.dispose
    @confirm_window.dispose
  end
  #--------------------------------------------------------------------------
  # * Frame Update
  #--------------------------------------------------------------------------
  def update
    super
    if @confirm_window.active
      @confirm_window.update
      update_confirm_selection
    else
      @window_slotlist.update
      update_savefile_selection
      if slot_index != @index
        if @data[slot_index]['state'] == :present
          @window_slotdetail.draw_data(@data[slot_index])
        else
          @window_slotdetail.draw_empty
        end
        @index = slot_index
      end
    end
  end
  #--------------------------------------------------------------------------
  # * Update Save File Selection
  #--------------------------------------------------------------------------
  def update_savefile_selection
    if Input.trigger?(Input::C)
      if @saving && FileTest.exist?(make_filename(slot_index))
        @confirm_window.visible = @confirm_window.active = true
        Sound.play_decision
      else
        determine_savefile
      end
    elsif Input.trigger?(Input::B)
      Sound.play_cancel
      return_scene
    end
  end
  #--------------------------------------------------------------------------
  # * Update Save File Selection
  #--------------------------------------------------------------------------
  def update_confirm_selection
    if Input.trigger?(Input::C) || Input.trigger?(Input::B)
      if Input.trigger?(Input::C) && @confirm_window.index == 0
        Sound.play_decision
        determine_savefile
      else
        Sound.play_cancel
      end
      @confirm_window.visible = @confirm_window.active = false
    end
  end
  #--------------------------------------------------------------------------
  # * Execute Save
  #--------------------------------------------------------------------------
  def do_save
    $game_temp.last_file_index = slot_index - 1
    File.open(make_filename(slot_index), "wb") do |file|
      write_save_data(file)
    end
    if Wora_NSS::SCENE_CHANGE
      $scene = Scene_Map.new
    else
      $scene = Scene_File.new(true, false, false)
    end
  end
  #--------------------------------------------------------------------------
  # * Execute Load
  #--------------------------------------------------------------------------
  def do_load
    File.open(make_filename(slot_index), "rb") do |file|
      read_save_data(file)
    end
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
      if FileTest.exist?(make_filename(slot_index))
        Sound.play_load
        do_load
      else
        Sound.play_buzzer
      end
    end
  end
  #--------------------------------------------------------------------------
  # * Make Filename
  #    file_index : save file index (0-3)
  #--------------------------------------------------------------------------
  def make_filename(file_index)
    Wora_NSS::SAVE_PATH + Wora_NSS::SAVE_FILE_NAME.gsub(/\{ID\}/i) { file_index.to_s }
  end
  #--------------------------------------------------------------------------
  # * Write Save Data
  #     file : write file object (opened)
  #--------------------------------------------------------------------------
  def write_save_data(file)
    old_write_save_data(file)
    Marshal.dump($game_temp.screenshot,         file)
  end
  #--------------------------------------------------------------------------
  # Slot Index
  #--------------------------------------------------------------------------
  def slot_index
    @window_slotlist.index + 1
  end
  #--------------------------------------------------------------------------
  # Set empty statev for slot
  #--------------------------------------------------------------------------
  def set_empty_state(slot_id)
    @data[slot_id] = { 'state' => :empty }
  end
  #--------------------------------------------------------------------------
  # Load data that will be displayed
  #--------------------------------------------------------------------------
  def load_display_data(slot_id)
    unless @data.has_key?(slot_id)
      @data[slot_id] = { 'state' => :present }
      file_name = make_filename(slot_id)
      # Start load data
      File.open(file_name, "r") do |file|
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
      end
    end
  end
  #-------------------------------------------------------------------------
  # * Get the Map name
  #-------------------------------------------------------------------------
  def get_mapname(map_id)
    @map_data ||= load_data("Data/MapInfos.rvdata")
    if Wora_NSS::MAP_NO_NAME_LIST.include?(map_id) && $game_switches[MAP_NO_NAME_SWITCH]
      map_name = MAP_NO_NAME
    else
      map_name = @map_data[map_id].name
    end 
    Wora_NSS::MAP_NAME_TEXT_SUB.each_index do |i|
      map_name.sub!(MAP_NAME_TEXT_SUB[i], '')
    end
    map_name
  end
end


#==============================================================================
# ** Window_SlotList
#------------------------------------------------------------------------------
#  Define a Save Slot List
#==============================================================================
class Window_SlotList < Window_Command
  #--------------------------------------------------------------------------
  # * Object Initialization
  #--------------------------------------------------------------------------
  def initialize(x, y, width, height, commands)
    super(width.to_i, commands)
    self.x = x.to_i
    self.y = y.to_i
    self.height = height.to_i
    self.opacity = Wora_NSS::NSS_WINDOW_OPACITY
    @index = $game_temp.last_file_index
  end
  #--------------------------------------------------------------------------
  # * Draw Item
  #--------------------------------------------------------------------------
  def draw_item(index, enabled = true)
    rect = item_rect(index)
    self.contents.clear_rect(rect)
    icon_index = enabled ? Wora_NSS::SAVED_SLOT_ICON :  Wora_NSS::EMPTY_SLOT_ICON
    draw_icon(icon_index, rect.x, rect.y, enabled) # Draw Icon
    rect.x += 26
    rect.width -= 20
    self.contents.font.color = normal_color
    self.contents.font.color.alpha = enabled ? 255 : 128
    self.contents.draw_text(rect, @commands[index])
  end
end

#==============================================================================
# ** Window_SlotList
#------------------------------------------------------------------------------
#  Define a Save Slot detail 
#==============================================================================

class Window_NSS_SlotDetail < Window_Base
  #-------------------------------------------------------------------------
  # * Object initialisation
  #-------------------------------------------------------------------------
  def initialize(x, y, width, height)
    super(x, y, width, height)
  end
  #-------------------------------------------------------------------------
  # * Draw empty slot content
  #-------------------------------------------------------------------------
  def draw_empty
    contents.clear
    contents.draw_text(0,0, contents.width, contents.height - WLH, Wora_NSS::EMPTY_SLOT_TEXT, 1)
  end
  #-------------------------------------------------------------------------
  # * Draw data in a slot
  #-------------------------------------------------------------------------
  def draw_data(data)
    contents.clear
    draw_screenshot(data['screenshot'])
    draw_gold(data['gamepar'].gold) if Wora_NSS::DRAW_GOLD
    draw_playtime(data['total_sec']) if Wora_NSS::DRAW_PLAYTIME
    draw_location(data['map_name']) if Wora_NSS::DRAW_LOCATION
    draw_actor_data(data['gamepar'].members)
  end
  #-------------------------------------------------------------------------
  # * Draw Screenshot
  #-------------------------------------------------------------------------
  def draw_screenshot(screenshot)
    inside_rect = Rect.new(0, 30, 352, 160)
    width = inside_rect.width - 4
    height = inside_rect.height - 4
    x = (Graphics.width - width) / 2
    y = (Graphics.height - height) / 2
    screenshot_rect = Rect.new(x, y, width, height)
    contents.fill_rect(inside_rect, Wora_NSS::MAP_BORDER)
    contents.blt(2, 32, screenshot, screenshot_rect)
  end
  #-------------------------------------------------------------------------
  # * Draw gold value
  #-------------------------------------------------------------------------
  def draw_gold(gold)
    contents.font.color = system_color
    contents.draw_text(0, 0, 150, WLH, Vocab::gold)
    contents.font.color = normal_color
    contents.draw_text(0, 0, 125, WLH, gold, 2) 
  end
  #-------------------------------------------------------------------------
  # * Draw playtime
  #-------------------------------------------------------------------------
  def draw_playtime(time)
    hour = time / 60 / 60
    min = time / 60 % 60
    sec = time % 60
    time_string = sprintf("%02d:%02d:%02d", hour, min, sec)
    pt_textsize = contents.text_size(Wora_NSS::PLAYTIME_TEXT).width
    ts_textsize = contents.text_size(time_string).width
    contents.font.color = system_color
    contents.draw_text(contents.width - ts_textsize - pt_textsize, 0,
    pt_textsize, WLH, Wora_NSS::PLAYTIME_TEXT)
    contents.font.color = normal_color
    contents.draw_text(0, 0, contents.width, WLH, time_string, 2)
  end
  #-------------------------------------------------------------------------
  # * Draw location
  #-------------------------------------------------------------------------
  def draw_location(mapname)
    lc_textsize = contents.text_size(Wora_NSS::LOCATION_TEXT).width
    mn_textsize = contents.text_size(mapname).width
    contents.font.color = system_color
    contents.draw_text(0, 190, contents.width, WLH, Wora_NSS::LOCATION_TEXT)
    contents.font.color = normal_color
    contents.draw_text(lc_textsize, 190, contents.width, WLH, mapname)
  end
  #-------------------------------------------------------------------------
  # * Draw actors' data
  #-------------------------------------------------------------------------
  def draw_actor_data(actors)
    actors.each_index do |i|
      actor = actors[i]
      face_x_base = (i*80) + (i*8)
      face_y_base = 216
      lvn_y_plus = 10
      lv_textsize = contents.text_size(actor.level).width
      lvt_textsize = contents.text_size(Wora_NSS::LV_TEXT).width
      if Wora_NSS::DRAW_FACE
        # Draw Face
        contents.fill_rect(face_x_base, face_y_base, 84, 84, Wora_NSS::FACE_BORDER)
        draw_face(actor.face_name, actor.face_index, face_x_base + 2,
        face_y_base + 2, 80)
      end
      if Wora_NSS::DRAW_LEVEL
        # Draw Level
        contents.font.color = system_color
        contents.draw_text(face_x_base + 2 + 80 - lv_textsize - lvt_textsize,
        face_y_base + 2 + 80 - WLH + lvn_y_plus, lvt_textsize, WLH, Wora_NSS::LV_TEXT)
        contents.font.color = normal_color
        contents.draw_text(face_x_base + 2 + 80 - lv_textsize,
        face_y_base + 2 + 80 - WLH + lvn_y_plus, lv_textsize, WLH, actor.level)
      end
      if Wora_NSS::DRAW_NAME
        # Draw Name
        contents.draw_text(face_x_base, face_y_base + 2 + 80 + lvn_y_plus - 6, 84,
        WLH, actor.name, 1)
      end
    end
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
