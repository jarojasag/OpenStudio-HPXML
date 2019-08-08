require 'csv'
require_relative "../../HPXMLtoOpenStudio/resources/airflow"
require_relative "../../HPXMLtoOpenStudio/resources/constructions"
require_relative "../../HPXMLtoOpenStudio/resources/geometry"
require_relative "../../HPXMLtoOpenStudio/resources/hotwater_appliances"
require_relative "../../HPXMLtoOpenStudio/resources/hpxml"
require_relative "../../HPXMLtoOpenStudio/resources/lighting"
require_relative "../../HPXMLtoOpenStudio/resources/pv"

class HEScoreRuleset
  def self.apply_ruleset(hpxml_doc)
    orig_details = hpxml_doc.elements["/HPXML/Building/BuildingDetails"]

    # Create new HPXML doc
    hpxml_values = HPXML.get_hpxml_values(hpxml: hpxml_doc.elements["/HPXML"])
    hpxml_values[:eri_calculation_version] = "2014AEG" # FIXME: Verify
    hpxml_doc = HPXML.create_hpxml(**hpxml_values)
    hpxml = hpxml_doc.elements["HPXML"]

    # BuildingSummary
    set_summary(orig_details, hpxml)

    # ClimateAndRiskZones
    set_climate(orig_details, hpxml)

    # Enclosure
    set_enclosure_air_infiltration(orig_details, hpxml)
    set_enclosure_roofs(orig_details, hpxml)
    set_enclosure_rim_joists(orig_details, hpxml)
    set_enclosure_walls(orig_details, hpxml)
    set_enclosure_foundation_walls(orig_details, hpxml)
    set_enclosure_framefloors(orig_details, hpxml)
    set_enclosure_slabs(orig_details, hpxml)
    set_enclosure_windows(orig_details, hpxml)
    set_enclosure_skylights(orig_details, hpxml)
    set_enclosure_doors(orig_details, hpxml)

    # Systems
    set_systems_hvac(orig_details, hpxml)
    set_systems_mechanical_ventilation(orig_details, hpxml)
    set_systems_water_heater(orig_details, hpxml)
    set_systems_water_heating_use(orig_details, hpxml)
    set_systems_photovoltaics(orig_details, hpxml)

    # Appliances
    set_appliances_clothes_washer(hpxml)
    set_appliances_clothes_dryer(hpxml)
    set_appliances_dishwasher(hpxml)
    set_appliances_refrigerator(hpxml)
    set_appliances_cooking_range_oven(hpxml)

    # Lighting
    set_lighting(orig_details, hpxml)
    set_ceiling_fans(orig_details, hpxml)

    # MiscLoads
    set_misc_plug_loads(hpxml)
    set_misc_television(hpxml)

    return hpxml_doc
  end

  def self.set_summary(orig_details, hpxml)
    # Get HPXML values
    orig_site_values = HPXML.get_site_values(site: orig_details.elements["BuildingSummary/Site"])
    @bldg_orient = orig_site_values[:orientation_of_front_of_home]
    @bldg_azimuth = orientation_to_azimuth(@bldg_orient)

    orig_building_construction_values = HPXML.get_building_construction_values(building_construction: orig_details.elements["BuildingSummary/BuildingConstruction"])
    @year_built = orig_building_construction_values[:year_built]
    @nbeds = orig_building_construction_values[:number_of_bedrooms]
    @cfa = orig_building_construction_values[:conditioned_floor_area] # ft^2
    @fnd_types = get_foundation_details(orig_details)
    @ducts = get_ducts_details(orig_details)
    @cfa_basement = @fnd_types["basement - conditioned"]
    @cfa_basement = 0 if @cfa_basement.nil?
    @ncfl_ag = orig_building_construction_values[:number_of_conditioned_floors_above_grade]
    @ceil_height = orig_building_construction_values[:average_ceiling_height] # ft

    # Calculate geometry
    # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope
    @has_cond_bsmnt = @fnd_types.keys.include?("basement - conditioned")
    @has_uncond_bsmnt = @fnd_types.keys.include?("basement - unconditioned")
    @ncfl = @ncfl_ag + (@has_cond_bsmnt ? 1 : 0)
    @nfl = @ncfl + (@has_uncond_bsmnt ? 1 : 0)
    @bldg_footprint = (@cfa - @cfa_basement) / @ncfl_ag # ft^2 FIXME: Verify. Does this change for shape=townhouse? Maybe ridge changes to front-back instead of left-right
    @bldg_length_side = (3.0 * @bldg_footprint / 5.0)**0.5 # ft
    @bldg_length_front = (5.0 / 3.0) * @bldg_length_side # ft
    @bldg_perimeter = 2.0 * @bldg_length_front + 2.0 * @bldg_length_side # ft
    @cvolume = @cfa * @ceil_height # ft^3 FIXME: Verify. Should this change for cathedral ceiling, conditioned basement, etc.?
    @roof_angle = 30.0 # deg

    HPXML.add_site(hpxml: hpxml,
                   fuels: ["electricity"], # TODO Check if changing this would ever influence results; if it does, talk to Leo
                   shelter_coefficient: Airflow.get_default_shelter_coefficient())

    # Neighboring buildings to left/right, 12ft offset, same height as building.
    # FIXME: Verify. What about townhouses?
    HPXML.add_site_neighbor(hpxml: hpxml,
                            azimuth: sanitize_azimuth(@bldg_azimuth + 90.0),
                            distance: 12.0)
    HPXML.add_site_neighbor(hpxml: hpxml,
                            azimuth: sanitize_azimuth(@bldg_azimuth - 90.0),
                            distance: 12.0)

    HPXML.add_building_occupancy(hpxml: hpxml,
                                 number_of_residents: Geometry.get_occupancy_default_num(@nbeds))

    HPXML.add_building_construction(hpxml: hpxml,
                                    number_of_conditioned_floors: @ncfl,
                                    number_of_conditioned_floors_above_grade: @ncfl_ag,
                                    number_of_bedrooms: @nbeds,
                                    conditioned_floor_area: @cfa,
                                    conditioned_building_volume: @cvolume,
                                    garage_present: false)
  end

  def self.set_climate(orig_details, hpxml)
    climate_and_risk_zones_values = HPXML.get_climate_and_risk_zones_values(climate_and_risk_zones: orig_details.elements["ClimateandRiskZones"])
    HPXML.add_climate_and_risk_zones(hpxml: hpxml, **climate_and_risk_zones_values)
    @iecc_zone = climate_and_risk_zones_values[:iecc2012]
  end

  def self.set_enclosure_air_infiltration(orig_details, hpxml)
    air_infil_values = HPXML.get_air_infiltration_measurement_values(air_infiltration_measurement: orig_details.elements["Enclosure/AirInfiltration/AirInfiltrationMeasurement"])
    cfm50 = air_infil_values[:air_leakage]
    desc = air_infil_values[:leakiness_description]

    # Convert to ACH50
    if not cfm50.nil?
      ach50 = cfm50 * 60.0 / @cvolume
    else
      ach50 = calc_ach50(@ncfl_ag, @cfa, @ceil_height, @cvolume, desc, @year_built, @iecc_zone, @fnd_types, @ducts)
    end

    HPXML.add_air_infiltration_measurement(hpxml: hpxml,
                                           id: air_infil_values[:id],
                                           house_pressure: 50,
                                           unit_of_measure: "ACH",
                                           air_leakage: ach50)
  end

  def self.set_enclosure_roofs(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Attics/Attic") do |orig_attic|
      attic_adjacent = get_attic_adjacent(orig_attic)

      # Roof: Two surfaces per HES zone_roof
      roof_id = HPXML.get_idref(orig_attic, "AttachedToRoof")
      roof = orig_details.elements["Enclosure/Roofs/Roof[SystemIdentifier[@id='#{roof_id}']]"]
      roof_values = HPXML.get_roof_values(roof: roof)
      if roof_values[:solar_absorptance].nil?
        roof_values[:solar_absorptance] = get_roof_solar_absorptance(roof_values[:roof_color])
      end
      roof_r = get_roof_assembly_r(roof_values[:insulation_cavity_r_value],
                                   roof_values[:insulation_continuous_r_value],
                                   roof_values[:roof_type],
                                   roof_values[:radiant_barrier])

      roof_azimuths = [@bldg_azimuth, @bldg_azimuth + 180] # FIXME: Verify
      roof_azimuths.each_with_index do |roof_azimuth, idx|
        HPXML.add_roof(hpxml: hpxml,
                       id: "#{roof_values[:id]}_#{idx}",
                       interior_adjacent_to: attic_adjacent,
                       area: 1000.0 / 2, # FIXME: Hard-coded. Use input if cathedral ceiling or conditioned attic, otherwise calculate default?
                       azimuth: sanitize_azimuth(roof_azimuth),
                       solar_absorptance: roof_values[:solar_absorptance],
                       emittance: 0.9, # ERI assumption; TODO get values from method
                       pitch: Math.tan(UnitConversions.convert(@roof_angle, "deg", "rad")) * 12,
                       radiant_barrier: false, # FIXME: Verify. Setting to false because it's included in the assembly R-value
                       insulation_assembly_r_value: roof_r)
      end
    end
  end

  def self.set_enclosure_rim_joists(orig_details, hpxml)
    # No rim joists
  end

  def self.set_enclosure_walls(orig_details, hpxml)
    # Above-grade walls
    orig_details.elements.each("Enclosure/Walls/Wall") do |orig_wall|
      wall_values = HPXML.get_wall_values(wall: orig_wall)

      wall_area = nil
      if @bldg_orient == wall_values[:orientation] or @bldg_orient == reverse_orientation(wall_values[:orientation])
        wall_area = @ceil_height * @bldg_length_front * @ncfl_ag # FIXME: Verify
      else
        wall_area = @ceil_height * @bldg_length_side * @ncfl_ag # FIXME: Verify
      end

      if wall_values[:wall_type] == "WoodStud"
        wall_r = get_wood_stud_wall_assembly_r(wall_values[:insulation_cavity_r_value],
                                               wall_values[:insulation_continuous_r_value],
                                               wall_values[:siding],
                                               wall_values[:optimum_value_engineering])
      elsif wall_values[:wall_type] == "StructuralBrick"
        wall_r = get_structural_block_wall_assembly_r(wall_values[:insulation_continuous_r_value])
      elsif wall_values[:wall_type] == "ConcreteMasonryUnit"
        wall_r = get_concrete_block_wall_assembly_r(wall_values[:insulation_cavity_r_value],
                                                    wall_values[:siding])
      elsif wall_values[:wall_type] == "StrawBale"
        wall_r = get_straw_bale_wall_assembly_r(wall_values[:siding])
      else
        fail "Unexpected wall type '#{wall_values[:wall_type]}'."
      end

      HPXML.add_wall(hpxml: hpxml,
                     id: wall_values[:id],
                     exterior_adjacent_to: "outside",
                     interior_adjacent_to: "living space",
                     wall_type: wall_values[:wall_type],
                     area: wall_area,
                     azimuth: orientation_to_azimuth(wall_values[:orientation]),
                     solar_absorptance: 0.75, # ERI assumption; TODO get values from method
                     emittance: 0.9, # ERI assumption; TODO get values from method
                     insulation_assembly_r_value: wall_r)
    end

    # Gable walls
    orig_details.elements.each("Enclosure/Attics/Attic") do |orig_attic|
      attic_adjacent = get_attic_adjacent(orig_attic)

      # Gable wall: Two surfaces per HES zone_roof
      # FIXME: Do we want gable walls even for cathedral ceiling and conditioned attic where roof area is provided by the user?
      gable_height = @bldg_length_side / 2 * Math.sin(UnitConversions.convert(@roof_angle, "deg", "rad"))
      gable_area = @bldg_length_side / 2 * gable_height
      gable_azimuths = [@bldg_azimuth + 90, @bldg_azimuth + 270] # FIXME: Verify
      gable_azimuths.each_with_index do |gable_azimuth, idx|
        HPXML.add_wall(hpxml: hpxml,
                       id: "#{HPXML.get_id(orig_attic)}_gable_#{idx}",
                       exterior_adjacent_to: "outside",
                       interior_adjacent_to: attic_adjacent,
                       wall_type: "WoodStud",
                       area: gable_area, # FIXME: Verify
                       azimuth: sanitize_azimuth(gable_azimuth),
                       solar_absorptance: 0.75, # ERI assumption; TODO get values from method
                       emittance: 0.9, # ERI assumption; TODO get values from method
                       insulation_assembly_r_value: 4.0) # FIXME: Hard-coded
      end
    end
  end

  def self.set_enclosure_foundation_walls(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Foundations/Foundation") do |orig_foundation|
      fnd_adjacent = get_foundation_adjacent(orig_foundation)

      if ["basement - unconditioned", "basement - conditioned", "crawlspace - vented", "crawlspace - unvented"].include? fnd_adjacent
        fndwall_id = HPXML.get_idref(orig_foundation, "AttachedToFoundationWall")
        fndwall = orig_details.elements["Enclosure/FoundationWalls/FoundationWall[SystemIdentifier[@id='#{fndwall_id}']]"]
        fndwall_values = HPXML.get_foundation_wall_values(foundation_wall: fndwall)
        # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/doe2-inputs-assumptions-and-calculations/the-doe2-model
        if ["basement - unconditioned", "basement - conditioned"].include? fnd_adjacent
          fndwall_height = 8.0 # FIXME: Verify
        else
          fndwall_height = 2.5 # FIXME: Verify
        end

        HPXML.add_foundation_wall(hpxml: hpxml,
                                  id: fndwall_values[:id],
                                  exterior_adjacent_to: "ground",
                                  interior_adjacent_to: fnd_adjacent,
                                  height: fndwall_height,
                                  area: fndwall_height * @bldg_perimeter, # FIXME: Verify
                                  thickness: 8, # FIXME: Verify
                                  depth_below_grade: fndwall_height, # FIXME: Verify
                                  insulation_assembly_r_value: fndwall_values[:insulation_r_value] + 3.0) # FIXME: need to convert from insulation R-value to assembly R-value
      end
    end
  end

  def self.set_enclosure_framefloors(orig_details, hpxml)
    # Floors above foundation
    orig_details.elements.each("Enclosure/Foundations/Foundation") do |orig_foundation|
      fnd_adjacent = get_foundation_adjacent(orig_foundation)

      framefloor_id = HPXML.get_idref(orig_foundation, "AttachedToFrameFloor")
      framefloor = orig_details.elements["Enclosure/FrameFloors/FrameFloor[SystemIdentifier[@id='#{framefloor_id}']]"]
      framefloor_values = HPXML.get_framefloor_values(framefloor: framefloor)
      if ["basement - unconditioned", "crawlspace - vented", "crawlspace - unvented"].include? fnd_adjacent
        framefloor_r = get_floor_assembly_r(framefloor_values[:insulation_cavity_r_value])

        HPXML.add_framefloor(hpxml: hpxml,
                             id: framefloor_values[:id],
                             exterior_adjacent_to: fnd_adjacent,
                             interior_adjacent_to: "living space",
                             area: framefloor_values[:area],
                             insulation_assembly_r_value: framefloor_r)
      end
    end

    # Floors below attic
    orig_details.elements.each("Enclosure/Attics/Attic") do |orig_attic|
      attic_adjacent = get_attic_adjacent(orig_attic)

      if ["attic - unvented", "attic - vented"].include? attic_adjacent
        framefloor_id = HPXML.get_idref(orig_attic, "AttachedToFrameFloor")
        framefloor = orig_details.elements["Enclosure/FrameFloors/FrameFloor[SystemIdentifier[@id='#{framefloor_id}']]"]
        framefloor_values = HPXML.get_framefloor_values(framefloor: framefloor)
        framefloor_r = get_ceiling_assembly_r(framefloor_values[:insulation_cavity_r_value])

        HPXML.add_framefloor(hpxml: hpxml,
                             id: framefloor_values[:id],
                             exterior_adjacent_to: attic_adjacent,
                             interior_adjacent_to: "living space",
                             area: 1000.0, # FIXME: Hard-coded. Use input if vented attic, otherwise calculate default?
                             insulation_assembly_r_value: framefloor_r)
      end
    end
  end

  def self.set_enclosure_slabs(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Foundations/Foundation") do |orig_foundation|
      fnd_adjacent = get_foundation_adjacent(orig_foundation)

      # Slab
      if fnd_adjacent == "living space"
        slab_id = HPXML.get_idref(orig_foundation, "AttachedToSlab")
        slab = orig_details.elements["Enclosure/Slabs/Slab[SystemIdentifier[@id='#{slab_id}']]"]
        slab_values = HPXML.get_slab_values(slab: slab)
      else
        framefloor_id = HPXML.get_idref(orig_foundation, "AttachedToFrameFloor")
        framefloor = orig_details.elements["Enclosure/FrameFloors/FrameFloor[SystemIdentifier[@id='#{framefloor_id}']]"]
        framefloor_values = HPXML.get_framefloor_values(framefloor: framefloor)

        slab_values = {}
        slab_values[:id] = "#{HPXML.get_id(orig_foundation)}_slab"
        slab_values[:area] = framefloor_values[:area]
        slab_values[:perimeter_insulation_r_value] = 0
      end

      HPXML.add_slab(hpxml: hpxml,
                     id: slab_values[:id],
                     interior_adjacent_to: fnd_adjacent,
                     area: slab_values[:area],
                     thickness: 4,
                     exposed_perimeter: @bldg_perimeter, # FIXME: Verify
                     perimeter_insulation_depth: 1, # FIXME: Hard-coded
                     under_slab_insulation_width: 0, # FIXME: Verify
                     depth_below_grade: 0, # FIXME: Verify
                     carpet_fraction: 0.5, # FIXME: Hard-coded
                     carpet_r_value: 2, # FIXME: Hard-coded
                     perimeter_insulation_r_value: slab_values[:perimeter_insulation_r_value],
                     under_slab_insulation_r_value: 0)
    end
  end

  def self.set_enclosure_windows(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Windows/Window") do |orig_window|
      window_values = HPXML.get_window_values(window: orig_window)

      if window_values[:ufactor].nil?
        window_frame_type = window_values[:frame_type]
        if window_frame_type == "Aluminum" and window_values[:aluminum_thermal_break]
          window_frame_type = "AluminumThermalBreak"
        end
        window_values[:ufactor], window_values[:shgc] = get_window_ufactor_shgc(window_frame_type,
                                                                                window_values[:glass_layers],
                                                                                window_values[:glass_type],
                                                                                window_values[:gas_fill])
      end

      if window_values[:exterior_shading] == "solar screens"
        # FIXME: Solar screen (add R-0.1 and multiply SHGC by 0.85?)
      end

      # Add one HPXML window per story (for this facade) to accommodate different overhang distances
      window_height = 4.0 # FIXME: Hard-coded
      for story in 1..@ncfl_ag
        HPXML.add_window(hpxml: hpxml,
                         id: "#{window_values[:id]}_story#{story}",
                         area: window_values[:area] / @ncfl_ag,
                         azimuth: orientation_to_azimuth(window_values[:orientation]),
                         ufactor: window_values[:ufactor],
                         shgc: window_values[:shgc],
                         overhangs_depth: 1.0, # FIXME: Verify
                         overhangs_distance_to_top_of_window: 2.0, # FIXME: Hard-coded
                         overhangs_distance_to_bottom_of_window: 6.0, # FIXME: Hard-coded
                         wall_idref: window_values[:wall_idref])
      end
      # Uses ERI Reference Home for interior shading
    end
  end

  def self.set_enclosure_skylights(orig_details, hpxml)
    orig_details.elements.each("Enclosure/Skylights/Skylight") do |orig_skylight|
      skylight_values = HPXML.get_skylight_values(skylight: orig_skylight)

      if skylight_values[:ufactor].nil?
        skylight_frame_type = skylight_values[:frame_type]
        if skylight_frame_type == "Aluminum" and skylight_values[:aluminum_thermal_break]
          skylight_frame_type = "AluminumThermalBreak"
        end
        skylight_values[:ufactor], skylight_values[:shgc] = get_skylight_ufactor_shgc(skylight_frame_type,
                                                                                      skylight_values[:glass_layers],
                                                                                      skylight_values[:glass_type],
                                                                                      skylight_values[:gas_fill])
      end

      if skylight_values[:exterior_shading] == "solar screens"
        # FIXME: Solar screen (add R-0.1 and multiply SHGC by 0.85?)
      end

      HPXML.add_skylight(hpxml: hpxml,
                         id: skylight_values[:id],
                         area: skylight_values[:area],
                         azimuth: orientation_to_azimuth(@bldg_orient), # FIXME: Hard-coded
                         ufactor: skylight_values[:ufactor],
                         shgc: skylight_values[:shgc],
                         roof_idref: "#{skylight_values[:roof_idref]}_0") # FIXME: Hard-coded
      # No overhangs
    end
  end

  def self.set_enclosure_doors(orig_details, hpxml)
    front_wall = nil
    orig_details.elements.each("Enclosure/Walls/Wall") do |orig_wall|
      wall_values = HPXML.get_wall_values(wall: orig_wall)
      next if wall_values[:orientation] != @bldg_orient

      front_wall = orig_wall
    end
    fail "Could not find front wall." if front_wall.nil?

    ufactor, shgc = Constructions.get_default_ufactor_shgc(@iecc_zone)

    front_wall_values = HPXML.get_wall_values(wall: front_wall)
    HPXML.add_door(hpxml: hpxml,
                   id: "Door",
                   wall_idref: front_wall_values[:id],
                   area: Constructions.get_default_door_area(),
                   azimuth: orientation_to_azimuth(@bldg_orient),
                   r_value: 1.0 / ufactor)
  end

  def self.set_systems_hvac(orig_details, hpxml)
    additional_hydronic_ids = []

    # HeatingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatingSystem") do |orig_heating|
      heating_values = HPXML.get_heating_system_values(heating_system: orig_heating)
      heating_values[:heating_capacity] = -1 # Use Manual J auto-sizing

      # Need to create hydronic distribution system?
      if heating_values[:heating_system_type] == "Boiler" and heating_values[:distribution_system_idref].nil?
        heating_values[:distribution_system_idref] = heating_values[:id] + "_dist"
        additional_hydronic_ids << heating_values[:distribution_system_idref]
      end

      if ["Furnace", "WallFurnace"].include? heating_values[:heating_system_type]
        if heating_values[:heating_system_fuel] == "electricity"
          heating_values[:heating_efficiency_afue] = 0.98
        elsif not heating_values[:year_installed].nil?
          heating_values[:heating_efficiency_afue] = lookup_hvac_efficiency(heating_values[:year_installed],
                                                                            heating_values[:heating_system_type],
                                                                            heating_values[:heating_system_fuel],
                                                                            "AFUE")
        end

      elsif heating_values[:heating_system_type] == "Boiler"
        if heating_values[:heating_system_fuel] == "electricity"
          heating_values[:heating_efficiency_afue] = 0.98
        elsif not heating_values[:year_installed].nil?
          heating_values[:heating_efficiency_afue] = lookup_hvac_efficiency(heating_values[:year_installed],
                                                                            heating_values[:heating_system_type],
                                                                            heating_values[:heating_system_fuel],
                                                                            "AFUE")
        end

      elsif heating_values[:heating_system_type] == "ElectricResistance"
        heating_values[:heating_efficiency_percent] = 0.98

      elsif heating_values[:heating_system_type] == "Stove"
        if heating_values[:heating_system_fuel] == "wood"
          heating_values[:heating_efficiency_percent] = 0.60
        elsif heating_values[:heating_system_fuel] == "wood pellets"
          heating_values[:heating_efficiency_percent] = 0.78
        end
      end

      HPXML.add_heating_system(hpxml: hpxml, **heating_values)
    end

    # CoolingSystem
    orig_details.elements.each("Systems/HVAC/HVACPlant/CoolingSystem") do |orig_cooling|
      cooling_values = HPXML.get_cooling_system_values(cooling_system: orig_cooling)
      cooling_values[:cooling_system_fuel] = "electricity"
      cooling_values[:cooling_capacity] = -1 # Use Manual J auto-sizing

      if cooling_values[:cooling_system_type] == "central air conditioner"
        if not cooling_values[:year_installed].nil?
          cooling_values[:cooling_efficiency_seer] = lookup_hvac_efficiency(cooling_values[:year_installed],
                                                                            cooling_values[:cooling_system_type],
                                                                            cooling_values[:cooling_system_fuel],
                                                                            "SEER")
        end

      elsif cooling_values[:cooling_system_type] == "room air conditioner"
        if not cooling_values[:year_installed].nil?
          cooling_values[:cooling_efficiency_eer] = lookup_hvac_efficiency(cooling_values[:year_installed],
                                                                           cooling_values[:cooling_system_type],
                                                                           cooling_values[:cooling_system_fuel],
                                                                           "EER")
        end
      end

      HPXML.add_cooling_system(hpxml: hpxml, **cooling_values)
    end

    # HeatPump
    orig_details.elements.each("Systems/HVAC/HVACPlant/HeatPump") do |orig_hp|
      hp_values = HPXML.get_heat_pump_values(heat_pump: orig_hp)
      hp_values[:heat_pump_fuel] = "electricity"
      hp_values[:cooling_capacity] = -1 # Use Manual J auto-sizing
      hp_values[:backup_heating_fuel] = "electricity"
      hp_values[:backup_heating_capacity] = -1 # Use Manual J auto-sizing
      hp_values[:backup_heating_efficiency_percent] = 1.0

      if hp_values[:heat_pump_type] == "air-to-air"
        if not hp_values[:year_installed].nil?
          hp_values[:cooling_efficiency_seer] = lookup_hvac_efficiency(hp_values[:year_installed],
                                                                       hp_values[:heat_pump_type],
                                                                       hp_values[:heat_pump_fuel],
                                                                       "SEER")
          hp_values[:heating_efficiency_hspf] = lookup_hvac_efficiency(hp_values[:year_installed],
                                                                       hp_values[:heat_pump_type],
                                                                       hp_values[:heat_pump_fuel],
                                                                       "HSPF")
        end
      end

      # If heat pump has no cooling/heating load served, assign arbitrary value for cooling/heating efficiency value
      if hp_values[:fraction_cool_load_served] == 0 and hp_values[:cooling_efficiency_seer].nil? and hp_values[:cooling_efficiency_eer].nil?
        if hp_values[:heat_pump_type] == "ground-to-air"
          hp_values[:cooling_efficiency_eer] = 16.6
        else
          hp_values[:cooling_efficiency_seer] = 13.0
        end
      end
      if hp_values[:fraction_heat_load_served] == 0 and hp_values[:heating_efficiency_hspf].nil? and hp_values[:heating_efficiency_cop].nil?
        if hp_values[:heat_pump_type] == "ground-to-air"
          hp_values[:heating_efficiency_cop] = 3.6
        else
          hp_values[:heating_efficiency_hspf] = 7.7
        end
      end

      HPXML.add_heat_pump(hpxml: hpxml, **hp_values)
    end

    # HVACControl
    HPXML.add_hvac_control(hpxml: hpxml,
                           id: "HVACControl",
                           control_type: "manual thermostat")

    # HVACDistribution
    orig_details.elements.each("Systems/HVAC/HVACDistribution") do |orig_dist|
      dist_values = HPXML.get_hvac_distribution_values(hvac_distribution: orig_dist)

      # Leakage fraction of total air handler flow
      # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/thermal-distribution-efficiency/thermal-distribution-efficiency
      # FIXME: Verify. Total or to the outside?
      # FIXME: Or 10%/25%? See https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI/edit#gid=1042407563
      if dist_values[:duct_system_sealed]
        leakage_frac = 0.03
      else
        leakage_frac = 0.15
      end

      # FIXME: Verify
      # Surface areas outside conditioned space
      # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/thermal-distribution-efficiency/thermal-distribution-efficiency
      supply_duct_area = 0.27 * @cfa
      return_duct_area = 0.05 * @nfl * @cfa

      new_dist = HPXML.add_hvac_distribution(hpxml: hpxml,
                                             id: dist_values[:id],
                                             distribution_system_type: "AirDistribution")
      new_air_dist = new_dist.elements["DistributionSystemType/AirDistribution"]

      # Supply duct leakage
      HPXML.add_duct_leakage_measurement(air_distribution: new_air_dist,
                                         duct_type: "supply",
                                         duct_leakage_value: 100) # FIXME: Hard-coded

      # Return duct leakage
      HPXML.add_duct_leakage_measurement(air_distribution: new_air_dist,
                                         duct_type: "return",
                                         duct_leakage_value: 100) # FIXME: Hard-coded

      orig_dist.elements.each("DistributionSystemType/AirDistribution/Ducts") do |orig_duct|
        duct_values = HPXML.get_ducts_values(ducts: orig_duct)

        if duct_values[:duct_location] == "attic - unconditioned"
          duct_values[:duct_location] = "attic - vented"
        end

        # FIXME: Verify nominal insulation and not assembly
        if duct_values[:duct_insulation_present]
          duct_rvalue = 6
        else
          duct_rvalue = 0
        end

        # Supply duct
        HPXML.add_ducts(air_distribution: new_air_dist,
                        duct_type: "supply",
                        duct_insulation_r_value: duct_rvalue,
                        duct_location: duct_values[:duct_location],
                        duct_surface_area: duct_values[:duct_fraction_area] * supply_duct_area)

        # Return duct
        HPXML.add_ducts(air_distribution: new_air_dist,
                        duct_type: "return",
                        duct_insulation_r_value: duct_rvalue,
                        duct_location: duct_values[:duct_location],
                        duct_surface_area: duct_values[:duct_fraction_area] * return_duct_area)
      end
    end

    additional_hydronic_ids.each do |hydronic_id|
      HPXML.add_hvac_distribution(hpxml: hpxml,
                                  id: hydronic_id,
                                  distribution_system_type: "HydronicDistribution")
    end
  end

  def self.set_systems_mechanical_ventilation(orig_details, hpxml)
    # No mechanical ventilation
  end

  def self.set_systems_water_heater(orig_details, hpxml)
    orig_details.elements.each("Systems/WaterHeating/WaterHeatingSystem") do |orig_wh_sys|
      wh_sys_values = HPXML.get_water_heating_system_values(water_heating_system: orig_wh_sys)

      if not wh_sys_values[:year_installed].nil?
        wh_sys_values[:energy_factor] = lookup_water_heater_efficiency(wh_sys_values[:year_installed],
                                                                       wh_sys_values[:fuel_type])
      end

      wh_capacity = nil
      if wh_sys_values[:water_heater_type] == "storage water heater"
        wh_capacity = get_default_water_heater_capacity(wh_sys_values[:fuel_type])
      end
      wh_recovery_efficiency = nil
      if wh_sys_values[:water_heater_type] == "storage water heater" and wh_sys_values[:fuel_type] != "electricity"
        wh_recovery_efficiency = get_default_water_heater_re(wh_sys_values[:fuel_type])
      end
      wh_tank_volume = nil
      if wh_sys_values[:water_heater_type] == "space-heating boiler with storage tank"
        wh_tank_volume = get_default_water_heater_volume("electricity")
      # Set default fuel_type to call function : get_default_water_heater_volume, not passing this input to EP-HPXML
      elsif wh_sys_values[:water_heater_type] != "instantaneous water heater" and wh_sys_values[:water_heater_type] != "space-heating boiler with tankless coil"
        wh_tank_volume = get_default_water_heater_volume(wh_sys_values[:fuel_type])
      end
      HPXML.add_water_heating_system(hpxml: hpxml,
                                     id: wh_sys_values[:id],
                                     fuel_type: wh_sys_values[:fuel_type],
                                     water_heater_type: wh_sys_values[:water_heater_type],
                                     location: "living space", # FIXME: To be decided later
                                     tank_volume: wh_tank_volume,
                                     fraction_dhw_load_served: 1.0,
                                     heating_capacity: wh_capacity,
                                     energy_factor: wh_sys_values[:energy_factor],
                                     uniform_energy_factor: wh_sys_values[:uniform_energy_factor],
                                     recovery_efficiency: wh_recovery_efficiency,
                                     related_hvac: wh_sys_values[:related_hvac])
    end
  end

  def self.set_systems_water_heating_use(orig_details, hpxml)
    # Hot water piping length
    piping_length = HotWaterAndAppliances.get_default_std_pipe_length(@has_uncond_bsmnt, @cfa, @ncfl)

    HPXML.add_hot_water_distribution(hpxml: hpxml,
                                     id: "HotWaterDistribution",
                                     system_type: "Standard",
                                     pipe_r_value: 0,
                                     standard_piping_length: piping_length)

    HPXML.add_water_fixture(hpxml: hpxml,
                            id: "ShowerHead",
                            water_fixture_type: "shower head",
                            low_flow: false)
  end

  def self.set_systems_photovoltaics(orig_details, hpxml)
    pv_values = HPXML.get_pv_system_values(pv_system: orig_details.elements["Systems/Photovoltaics/PVSystem"])
    return if pv_values.nil?

    if pv_values[:max_power_output].nil?
      # Estimate from year and # modules
      module_power = PV.calc_module_power_from_year(pv_values[:year_modules_manufactured]) # W/panel
      pv_values[:max_power_output] = pv_values[:number_of_panels] * module_power
    end

    # Estimate PV panel losses from year
    losses_fraction = PV.calc_losses_fraction_from_year(pv_values[:year_modules_manufactured])

    HPXML.add_pv_system(hpxml: hpxml,
                        id: "PVSystem",
                        location: "roof",
                        module_type: "standard", # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                        tracking: "fixed",
                        array_azimuth: orientation_to_azimuth(pv_values[:array_orientation]),
                        array_tilt: @roof_angle,
                        max_power_output: pv_values[:max_power_output],
                        inverter_efficiency: 0.96, # From https://docs.google.com/spreadsheets/d/1YeoVOwu9DU-50fxtT_KRh_BJLlchF7nls85Ebe9fDkI
                        system_losses_fraction: losses_fraction)
  end

  def self.set_appliances_clothes_washer(hpxml)
    HPXML.add_clothes_washer(hpxml: hpxml,
                             id: "ClothesWasher",
                             location: "living space", # FIXME: Verify
                             modified_energy_factor: HotWaterAndAppliances.calc_clothes_washer_mef_from_imef(HotWaterAndAppliances.get_clothes_washer_reference_imef()),
                             rated_annual_kwh: HotWaterAndAppliances.get_clothes_washer_reference_ler(),
                             label_electric_rate: HotWaterAndAppliances.get_clothes_washer_reference_elec_rate(),
                             label_gas_rate: HotWaterAndAppliances.get_clothes_washer_reference_gas_rate(),
                             label_annual_gas_cost: HotWaterAndAppliances.get_clothes_washer_reference_agc(),
                             capacity: HotWaterAndAppliances.get_clothes_washer_reference_cap())
  end

  def self.set_appliances_clothes_dryer(hpxml)
    HPXML.add_clothes_dryer(hpxml: hpxml,
                            id: "ClothesDryer",
                            location: "living space", # FIXME: Verify
                            fuel_type: "electricity",
                            energy_factor: HotWaterAndAppliances.calc_clothes_dryer_ef_from_cef(HotWaterAndAppliances.get_clothes_dryer_reference_cef(Constants.FuelTypeElectric)),
                            control_type: HotWaterAndAppliances.get_clothes_dryer_reference_control())
  end

  def self.set_appliances_dishwasher(hpxml)
    HPXML.add_dishwasher(hpxml: hpxml,
                         id: "Dishwasher",
                         energy_factor: HotWaterAndAppliances.get_dishwasher_reference_ef(),
                         place_setting_capacity: HotWaterAndAppliances.get_dishwasher_reference_cap())
  end

  def self.set_appliances_refrigerator(hpxml)
    HPXML.add_refrigerator(hpxml: hpxml,
                           id: "Refrigerator",
                           location: "living space", # FIXME: Verify
                           rated_annual_kwh: HotWaterAndAppliances.get_refrigerator_reference_annual_kwh(@nbeds))
  end

  def self.set_appliances_cooking_range_oven(hpxml)
    HPXML.add_cooking_range(hpxml: hpxml,
                            id: "CookingRange",
                            fuel_type: "electricity",
                            is_induction: HotWaterAndAppliances.get_range_oven_reference_is_induction())

    HPXML.add_oven(hpxml: hpxml,
                   id: "Oven",
                   is_convection: HotWaterAndAppliances.get_range_oven_reference_is_convection())
  end

  def self.set_lighting(orig_details, hpxml)
    fFI_int, fFI_ext, fFI_grg, fFII_int, fFII_ext, fFII_grg = Lighting.get_reference_fractions()
    HPXML.add_lighting(hpxml: hpxml,
                       fraction_tier_i_interior: fFI_int,
                       fraction_tier_i_exterior: fFI_ext,
                       fraction_tier_i_garage: fFI_grg,
                       fraction_tier_ii_interior: fFII_int,
                       fraction_tier_ii_exterior: fFII_ext,
                       fraction_tier_ii_garage: fFII_grg)
  end

  def self.set_ceiling_fans(orig_details, hpxml)
    # No ceiling fans
  end

  def self.set_misc_plug_loads(hpxml)
    HPXML.add_plug_load(hpxml: hpxml,
                        id: "PlugLoadOther",
                        plug_load_type: "other")
    # Uses ERI Reference Home for performance
  end

  def self.set_misc_television(hpxml)
    HPXML.add_plug_load(hpxml: hpxml,
                        id: "PlugLoadTV",
                        plug_load_type: "TV other")
    # Uses ERI Reference Home for performance
  end
end

def lookup_hvac_efficiency(year, hvac_type, fuel_type, units)
  if year < 1970
    year = 1970
  elsif year > 2010
    year = 2010
  end

  type_id = { 'central air conditioner' => 'split_dx',
              'room air conditioner' => 'packaged_dx',
              'air-to-air' => 'heat_pump',
              'Furnace' => 'central_furnace',
              'WallFurnace' => 'wall_furnace',
              'Boiler' => 'boiler' }[hvac_type]
  fail "Unexpected hvac_type #{hvac_type}." if type_id.nil?

  fuel_primary_id = hpxml_to_hescore_fuel(fuel_type)
  fail "Unexpected fuel_type #{fuel_type}." if fuel_primary_id.nil?

  metric_id = units.downcase

  value = nil
  CSV.foreach(File.join(File.dirname(__FILE__), "lu_hvac_equipment_efficiency.csv"), headers: true) do |row|
    next unless Integer(row['year']) == year
    next unless row['type_id'] == type_id
    next unless row['fuel_primary_id'] == fuel_primary_id
    next unless row['metric_id'] == metric_id

    value = Float(row['value'])
    break
  end
  fail "Could not lookup default HVAC efficiency." if value.nil?

  return value
end

def lookup_water_heater_efficiency(year, fuel_type)
  if year < 1972
    year = 1972
  elsif year > 2010
    year = 2010
  end

  fuel_primary_id = hpxml_to_hescore_fuel(fuel_type)
  fail "Unexpected fuel_type #{fuel_type}." if fuel_primary_id.nil?

  value = nil
  CSV.foreach(File.join(File.dirname(__FILE__), "lu_water_heater_efficiency.csv"), headers: true) do |row|
    next unless Integer(row['year']) == year
    next unless row['fuel_primary_id'] == fuel_primary_id

    value = Float(row['value'])
    break
  end
  fail "Could not lookup default water heating efficiency." if value.nil?

  return value
end

def get_default_water_heater_volume(fuel)
  # Water Heater Tank Volume by fuel
  val = { "electricity" => 50,
          "natural gas" => 40,
          "propane" => 40,
          "fuel oil" => 32 }[fuel]
  return val if not val.nil?

  fail "Could not get default water heater volume for fuel '#{fuel}'"
end

def get_default_water_heater_re(fuel)
  # Water Heater Recovery Efficiency by fuel
  val = { "electricity" => 0.98,
          "natural gas" => 0.76,
          "propane" => 0.76,
          "fuel oil" => 0.76 }[fuel]
  return val if not val.nil?

  fail "Could not get default water heater RE for fuel '#{fuel}'"
end

def get_default_water_heater_capacity(fuel)
  # Water Heater Rated Input Capacity by fuel
  val = { "electricity" => 15400,
          "natural gas" => 38000,
          "propane" => 38000,
          "fuel oil" => 90000 }[fuel]
  return val if not val.nil?

  fail "Could not get default water heater capacity for fuel '#{fuel}'"
end

def get_wood_stud_wall_assembly_r(r_cavity, r_cont, siding, ove)
  # Walls Wood Stud Assembly R-value
  # FIXME: Verify
  # FIXME: Need values below where nil
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  sidings = ["wood siding",     # Wood Siding
             "stucco",          # Stucco Finish
             "vinyl siding",    # Vinyl Siding
             "aluminum siding", # Aluminum Siding
             "brick veneer"]    # Brick Veneer
  siding_index = sidings.index(siding)
  has_r_cont = !r_cont.nil?
  if not has_r_cont and not ove
    # Wood Frame
    val = { 0.0 => [4.6, 3.2, 3.8, 3.7, 4.7],                                # ewwf00wo, ewwf00st, ewwf00vi, ewwf00al, ewwf00br
            3.0 => [7.0, 5.8, 6.3, 6.2, 7.1],                                # ewwf03wo, ewwf03st, ewwf03vi, ewwf03al, ewwf03br
            7.0 => [9.7, 8.5, 9.0, 8.8, 9.8],                                # ewwf07wo, ewwf07st, ewwf07vi, ewwf07al, ewwf07br
            11.0 => [11.5, 10.2, 10.8, 10.6, 11.6],                          # ewwf11wo, ewwf11st, ewwf11vi, ewwf11al, ewwf11br
            13.0 => [12.5, 11.1, 11.6, 11.5, 12.5],                          # ewwf13wo, ewwf13st, ewwf13vi, ewwf13al, ewwf13br
            15.0 => [13.3, 11.9, 12.5, 12.3, 13.3],                          # ewwf15wo, ewwf15st, ewwf15vi, ewwf15al, ewwf15br
            19.0 => [16.9, 15.4, 16.1, 15.9, 16.9],                          # ewwf19wo, ewwf19st, ewwf19vi, ewwf19al, ewwf19br
            21.0 => [17.5, 16.1, 16.9, 16.7, 17.9] }[r_cavity][siding_index] # ewwf21wo, ewwf21st, ewwf21vi, ewwf21al, ewwf21br
  elsif has_r_cont and not ove
    # Wood Frame with Rigid Foam Sheathing
    val = { 0.0 => [nil, nil, nil, nil, nil],                                # ewps00wo, ewps00st, ewps00vi, ewps00al, ewps00br
            3.0 => [nil, nil, nil, nil, nil],                                # ewps03wo, ewps03st, ewps03vi, ewps03al, ewps03br
            7.0 => [nil, nil, nil, nil, nil],                                # ewps07wo, ewps07st, ewps07vi, ewps07al, ewps07br
            11.0 => [16.7, 15.4, 15.9, 15.9, 16.9],                          # ewps11wo, ewps11st, ewps11vi, ewps11al, ewps11br
            13.0 => [17.9, 16.4, 16.9, 16.9, 17.9],                          # ewps13wo, ewps13st, ewps13vi, ewps13al, ewps13br
            15.0 => [18.5, 17.2, 17.9, 17.9, 18.9],                          # ewps15wo, ewps15st, ewps15vi, ewps15al, ewps15br
            19.0 => [22.2, 20.8, 21.3, 21.3, 22.2],                          # ewps19wo, ewps19st, ewps19vi, ewps19al, ewps19br
            21.0 => [22.7, 21.7, 22.2, 22.2, 23.3] }[r_cavity][siding_index] # ewps21wo, ewps21st, ewps21vi, ewps21al, ewps21br
  elsif not has_r_cont and ove
    # Wood Frame with Optimal Value Engineering
    val = { 19.0 => [19.2, 17.9, 18.5, 18.2, 19.2],                          # ewov19wo, ewov19st, ewov19vi, ewov19al, ewov19br
            21.0 => [20.4, 18.9, 19.6, 19.6, 20.4],                          # ewov21wo, ewov21st, ewov21vi, ewov21al, ewov21br
            27.0 => [25.6, 24.4, 25.0, 24.4, 25.6],                          # ewov27wo, ewov27st, ewov27vi, ewov27al, ewov27br
            33.0 => [30.3, 29.4, 29.4, 29.4, 30.3],                          # ewov33wo, ewov33st, ewov33vi, ewov33al, ewov33br
            38.0 => [34.5, 33.3, 34.5, 34.5, 34.5] }[r_cavity][siding_index] # ewov38wo, ewov38st, ewov38vi, ewov38al, ewov38br
  end
  return val if not val.nil?

  fail "Could not get default wood stud wall assembly R-value for R-cavity '#{r_cavity}' and R-cont '#{r_cont}' and siding '#{siding}' and ove '#{ove}'"
end

def get_structural_block_wall_assembly_r(r_cont)
  # Walls Structural Block Assembly R-value
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  val = { nil => 2.9, # ewbr00nn
          5.0 => 7.9,            # ewbr05nn
          10.0 => 12.8 }[r_cont] # ewbr10nn
  return val if not val.nil?

  fail "Could not get default structural block wall assembly R-value for R-cavity '#{r_cont}'"
end

def get_concrete_block_wall_assembly_r(r_cavity, siding)
  # Walls Concrete Block Assembly R-value
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  sidings = ["stucco",       # Stucco Finish
             "brick veneer", # Brick Veneer
             nil]            # None
  siding_index = sidings.index(siding)
  val = { 0.0 => [4.1, 5.6, 4.0],                           # ewcb00st, ewcb00br, ewcb00nn
          3.0 => [5.7, 7.2, 5.6],                           # ewcb03st, ewcb03br, ewcb03nn
          6.0 => [8.5, 10.0, 8.3] }[r_cavity][siding_index] # ewcb06st, ewcb06br, ewcb06nn
  return val if not val.nil?

  fail "Could not get default concrete block wall assembly R-value for R-cavity '#{r_cavity}' and siding '#{siding}'"
end

def get_straw_bale_wall_assembly_r(siding)
  # Walls Straw Bale Assembly R-value
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/wall-construction-types
  return 58.8 if siding == "stucco" # ewsb00st

  fail "Could not get default straw bale assembly R-value for siding '#{siding}'"
end

def get_roof_assembly_r(r_cavity, r_cont, material, has_radiant_barrier)
  # Roof Assembly R-value
  # FIXME: Verify
  # FIXME: Need values below where nil
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/roof-construction-types
  materials = ["asphalt or fiberglass shingles",    # Composition Shingles
               "wood shingles or shakes",           # Wood Shakes
               "slate or tile shingles",            # Clay Tile
               "concrete",                          # Concrete Tile
               "plastic/rubber/synthetic sheeting"] # Tar and Gravel
  material_index = materials.index(material)
  has_r_cont = !r_cont.nil?
  if not has_r_cont and not has_radiant_barrier
    # Wood Frame
    val = { 0.0 => [3.3, 4.0, 3.4, 3.4, 3.7],                                 # rfwf00co, rfwf00wo, rfwf00rc, rfwf00lc, rfwf00tg
            11.0 => [13.5, 14.3, 13.7, 13.5, 13.9],                           # rfwf11co, rfwf11wo, rfwf11rc, rfwf11lc, rfwf11tg
            13.0 => [14.9, 15.6, 15.2, 14.9, 15.4],                           # rfwf13co, rfwf13wo, rfwf13rc, rfwf13lc, rfwf13tg
            15.0 => [16.4, 16.9, 16.4, 16.4, 16.7],                           # rfwf15co, rfwf15wo, rfwf15rc, rfwf15lc, rfwf15tg
            19.0 => [20.0, 20.8, 20.4, 20.4, 20.4],                           # rfwf19co, rfwf19wo, rfwf19rc, rfwf19lc, rfwf19tg
            21.0 => [21.7, 22.2, 21.7, 21.3, 21.7],                           # rfwf21co, rfwf21wo, rfwf21rc, rfwf21lc, rfwf21tg
            27.0 => [nil, 27.8, 27.0, 27.0, 27.0],                            # rfwf27co, rfwf27wo, rfwf27rc, rfwf27lc, rfwf27tg
            30.0 => [nil, nil, nil, nil, nil] }[r_cavity][material_index]     # rfwf30co, rfwf30wo, rfwf30rc, rfwf30lc, rfwf30tg
  elsif not has_r_cont and has_radiant_barrier
    # Wood Frame with Radiant Barrier
    val = { 0.0 => [5.6, 6.3, 5.7, 5.6, 6.0] }[r_cavity][material_index] # rfrb00co, rfrb00wo, rfrb00rc, rfrb00lc, rfrb00tg
  elsif has_r_cont and not has_radiant_barrier
    # Wood Frame with Rigid Foam Sheathing
    val = { 0.0 => [8.3, 9.0, 8.4, 8.3, 8.7],                                 # rfps00co, rfps00wo, rfps00rc, rfps00lc, rfps00tg
            11.0 => [18.5, 19.2, 18.5, 18.5, 18.9],                           # rfps11co, rfps11wo, rfps11rc, rfps11lc, rfps11tg
            13.0 => [20.0, 20.8, 20.0, 20.0, 20.4],                           # rfps13co, rfps13wo, rfps13rc, rfps13lc, rfps13tg
            15.0 => [21.3, 22.2, 21.3, 21.3, 21.7],                           # rfps15co, rfps15wo, rfps15rc, rfps15lc, rfps15tg
            19.0 => [nil, 25.6, 25.6, 25.0, 25.6],                            # rfps19co, rfps19wo, rfps19rc, rfps19lc, rfps19tg
            21.0 => [nil, 27.0, 27.0, 26.3, 27.0] }[r_cavity][material_index] # rfps21co, rfps21wo, rfps21rc, rfps21lc, rfps21tg
  end
  return val if not val.nil?

  fail "Could not get default roof assembly R-value for R-cavity '#{r_cavity}' and R-cont '#{r_cont}' and material '#{material}' and radiant barrier '#{has_radiant_barrier}'"
end

def get_ceiling_assembly_r(r_cavity)
  # Ceiling Assembly R-value
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/ceiling-construction-types
  val = { 0.0 => 2.2,              # ecwf00
          3.0 => 5.0,              # ecwf03
          6.0 => 7.6,              # ecwf06
          9.0 => 10.0,             # ecwf09
          11.0 => 10.9,            # ecwf11
          19.0 => 19.2,            # ecwf19
          21.0 => 21.3,            # ecwf21
          25.0 => 25.6,            # ecwf25
          30.0 => 30.3,            # ecwf30
          38.0 => 38.5,            # ecwf38
          44.0 => 43.5,            # ecwf44
          49.0 => 50.0,            # ecwf49
          60.0 => 58.8 }[r_cavity] # ecwf60
  return val if not val.nil?

  fail "Could not get default ceiling assembly R-value for R-cavity '#{r_cavity}'"
end

def get_floor_assembly_r(r_cavity)
  # Floor Assembly R-value
  # FIXME: Verify
  # FIXME: Does this include air films?
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/building-envelope/floor-construction-types
  val = { 0.0 => 5.9,              # efwf00ca
          11.0 => 15.6,            # efwf11ca
          13.0 => 17.2,            # efwf13ca
          15.0 => 18.5,            # efwf15ca
          19.0 => 22.2,            # efwf19ca
          21.0 => 23.8,            # efwf21ca
          25.0 => 27.0,            # efwf25ca
          30.0 => 31.3,            # efwf30ca
          38.0 => 37.0 }[r_cavity] # efwf38ca
  return val if not val.nil?

  fail "Could not get default floor assembly R-value for R-cavity '#{r_cavity}'"
end

def get_window_ufactor_shgc(frame_type, glass_layers, glass_type, gas_fill)
  # Window U-factor/SHGC
  # FIXME: Verify
  # https://docs.google.com/spreadsheets/d/1joG39BeiRj1mV0Lge91P_dkL-0-94lSEY5tJzGvpc2A/edit#gid=909262753
  key = [frame_type, glass_layers, glass_type, gas_fill]
  vals = { ["Aluminum", "single-pane", nil, nil] => [1.27, 0.75],                               # scna
           ["Wood", "single-pane", nil, nil] => [0.89, 0.64],                                   # scnw
           ["Aluminum", "single-pane", "tinted/reflective", nil] => [1.27, 0.64],               # stna
           ["Wood", "single-pane", "tinted/reflective", nil] => [0.89, 0.54],                   # stnw
           ["Aluminum", "double-pane", nil, "air"] => [0.81, 0.67],                             # dcaa
           ["AluminumThermalBreak", "double-pane", nil, "air"] => [0.60, 0.67],                 # dcab
           ["Wood", "double-pane", nil, "air"] => [0.51, 0.56],                                 # dcaw
           ["Aluminum", "double-pane", "tinted/reflective", "air"] => [0.81, 0.55],             # dtaa
           ["AluminumThermalBreak", "double-pane", "tinted/reflective", "air"] => [0.60, 0.55], # dtab
           ["Wood", "double-pane", "tinted/reflective", "air"] => [0.51, 0.46],                 # dtaw
           ["Wood", "double-pane", "low-e", "air"] => [0.42, 0.52],                             # dpeaw
           ["AluminumThermalBreak", "double-pane", "low-e", "argon"] => [0.47, 0.62],           # dpeaab
           ["Wood", "double-pane", "low-e", "argon"] => [0.39, 0.52],                           # dpeaaw
           ["Aluminum", "double-pane", "reflective", "air"] => [0.67, 0.37],                    # dseaa
           ["AluminumThermalBreak", "double-pane", "reflective", "air"] => [0.47, 0.37],        # dseab
           ["Wood", "double-pane", "reflective", "air"] => [0.39, 0.31],                        # dseaw
           ["Wood", "double-pane", "reflective", "argon"] => [0.36, 0.31],                      # dseaaw
           ["Wood", "triple-pane", "low-e", "argon"] => [0.27, 0.31] }[key]                     # thmabw
  return vals if not vals.nil?

  fail "Could not get default window U/SHGC for frame type '#{frame_type}' and glass layers '#{glass_layers}' and glass type '#{glass_type}' and gas fill '#{gas_fill}'"
end

def get_skylight_ufactor_shgc(frame_type, glass_layers, glass_type, gas_fill)
  # Skylight U-factor/SHGC
  # FIXME: Verify
  # https://docs.google.com/spreadsheets/d/1joG39BeiRj1mV0Lge91P_dkL-0-94lSEY5tJzGvpc2A/edit#gid=909262753
  key = [frame_type, glass_layers, glass_type, gas_fill]
  vals = { ["Aluminum", "single-pane", nil, nil] => [1.98, 0.75],                               # scna
           ["Wood", "single-pane", nil, nil] => [1.47, 0.64],                                   # scnw
           ["Aluminum", "single-pane", "tinted/reflective", nil] => [1.98, 0.64],               # stna
           ["Wood", "single-pane", "tinted/reflective", nil] => [1.47, 0.54],                   # stnw
           ["Aluminum", "double-pane", nil, "air"] => [1.30, 0.67],                             # dcaa
           ["AluminumThermalBreak", "double-pane", nil, "air"] => [1.10, 0.67],                 # dcab
           ["Wood", "double-pane", nil, "air"] => [0.84, 0.56],                                 # dcaw
           ["Aluminum", "double-pane", "tinted/reflective", "air"] => [1.30, 0.55],             # dtaa
           ["AluminumThermalBreak", "double-pane", "tinted/reflective", "air"] => [1.10, 0.55], # dtab
           ["Wood", "double-pane", "tinted/reflective", "air"] => [0.84, 0.46],                 # dtaw
           ["Wood", "double-pane", "low-e", "air"] => [0.74, 0.52],                             # dpeaw
           ["AluminumThermalBreak", "double-pane", "low-e", "argon"] => [0.95, 0.62],           # dpeaab
           ["Wood", "double-pane", "low-e", "argon"] => [0.68, 0.52],                           # dpeaaw
           ["Aluminum", "double-pane", "reflective", "air"] => [1.17, 0.37],                    # dseaa
           ["AluminumThermalBreak", "double-pane", "reflective", "air"] => [0.98, 0.37],        # dseab
           ["Wood", "double-pane", "reflective", "air"] => [0.71, 0.31],                        # dseaw
           ["Wood", "double-pane", "reflective", "argon"] => [0.65, 0.31],                      # dseaaw
           ["Wood", "triple-pane", "low-e", "argon"] => [0.47, 0.31] }[key]                     # thmabw
  return vals if not vals.nil?

  fail "Could not get default skylight U/SHGC for frame type '#{frame_type}' and glass layers '#{glass_layers}' and glass type '#{glass_type}' and gas fill '#{gas_fill}'"
end

def get_roof_solar_absorptance(roof_color)
  # FIXME: Verify
  # https://docs.google.com/spreadsheets/d/1joG39BeiRj1mV0Lge91P_dkL-0-94lSEY5tJzGvpc2A/edit#gid=1325866208
  val = { "reflective" => 0.40,
          "white" => 0.50,
          "light" => 0.65,
          "medium" => 0.75,
          "medium dark" => 0.85,
          "dark" => 0.95 }[roof_color]
  return val if not val.nil?

  fail "Could not get roof absorptance for color '#{roof_color}'"
end

def calc_ach50(ncfl_ag, cfa, ceil_height, cvolume, desc, year_built, iecc_cz, fnd_types, ducts)
  # http://hes-documentation.lbl.gov/calculation-methodology/calculation-of-energy-consumption/heating-and-cooling-calculation/infiltration/infiltration

  # Constants
  c_floor_area = -0.002078
  c_height = 0.06375

  # Vintage
  c_vintage = nil
  if year_built < 1960
    c_vintage = -0.2498
  elsif year_built <= 1969
    c_vintage = -0.4327
  elsif year_built <= 1979
    c_vintage = -0.4521
  elsif year_built <= 1989
    c_vintage = -0.6536
  elsif year_built <= 1999
    c_vintage = -0.9152
  elsif year_built >= 2000
    c_vintage = -1.058
  else
    fail "Unexpected vintage: #{year_built}"
  end

  # Climate zone
  c_iecc = nil
  if iecc_cz == "1A" or iecc_cz == "2A"
    c_iecc = 0.4727
  elsif iecc_cz == "3A"
    c_iecc = 0.2529
  elsif iecc_cz == "4A"
    c_iecc = 0.3261
  elsif iecc_cz == "5A"
    c_iecc = 0.1118
  elsif iecc_cz == "6A" or iecc_cz == "7"
    c_iecc = 0.0
  elsif iecc_cz == "2B" or iecc_cz == "3B"
    c_iecc = -0.03755
  elsif iecc_cz == "4B" or iecc_cz == "5B"
    c_iecc = -0.008774
  elsif iecc_cz == "6B"
    c_iecc = 0.01944
  elsif iecc_cz == "3C"
    c_iecc = 0.04827
  elsif iecc_cz == "4C"
    c_iecc = 0.2584
  elsif iecc_cz == "8"
    c_iecc = -0.5119
  else
    fail "Unexpected IECC climate zone: #{c_iecc}"
  end

  # Foundation type (weight by area)
  c_foundation = 0.0
  sum_fnd_area = 0.0
  fnd_types.each do |fnd_type, area|
    sum_fnd_area += area
    if fnd_type == "living space"
      c_foundation += -0.036992 * area
    elsif fnd_type == "basement - conditioned" or fnd_type == "crawlspace - unvented"
      c_foundation += 0.108713 * area
    elsif fnd_type == "basement - unconditioned" or fnd_type == "crawlspace - vented"
      c_foundation += 0.180352 * area
    else
      fail "Unexpected foundation type: #{fnd_type}"
    end
  end
  c_foundation /= sum_fnd_area

  # Ducts (weighted by duct fraction and hvac fraction)
  c_duct = 0.0
  ducts.each do |hvac_frac, duct_frac, duct_location|
    if duct_location == "living space"
      c_duct += -0.12381 * duct_frac * hvac_frac
    elsif duct_location == "attic - unconditioned" or duct_location == "basement - unconditioned"
      c_duct += 0.07126 * duct_frac * hvac_frac
    elsif duct_location == "crawlspace - vented"
      c_duct += 0.18072 * duct_frac * hvac_frac
    elsif duct_location == "crawlspace - unvented"
      c_duct += 0.07126 * duct_frac * hvac_frac
    else
      fail "Unexpected duct location: #{duct_location}"
    end
  end

  c_sealed = nil
  if desc == "tight"
    c_sealed = -0.288
  elsif desc == "average"
    c_sealed = 0.0
  else
    fail "Unexpected air leakage description: #{desc}"
  end

  floor_area_m2 = UnitConversions.convert(cfa, "ft^2", "m^2")
  height_m = UnitConversions.convert(ncfl_ag * ceil_height, "ft", "m") + 0.5

  # Normalized leakage
  nl = Math.exp(floor_area_m2 * c_floor_area +
                height_m * c_height +
                c_sealed + c_vintage + c_iecc + c_foundation + c_duct)

  # Specific Leakage Area
  sla = nl / (1000.0 * ncfl_ag**0.3)

  ach50 = Airflow.get_infiltration_ACH50_from_SLA(sla, 0.65, cfa, cvolume)

  return ach50
end

def orientation_to_azimuth(orientation)
  return { "northeast" => 45,
           "east" => 90,
           "southeast" => 135,
           "south" => 180,
           "southwest" => 225,
           "west" => 270,
           "northwest" => 315,
           "north" => 0 }[orientation]
end

def reverse_orientation(orientation)
  # Converts, e.g., "northwest" to "southeast"
  reverse = orientation
  if reverse.include? "north"
    reverse = reverse.gsub("north", "south")
  else
    reverse = reverse.gsub("south", "north")
  end
  if reverse.include? "east"
    reverse = reverse.gsub("east", "west")
  else
    reverse = reverse.gsub("west", "east")
  end
  return reverse
end

def sanitize_azimuth(azimuth)
  # Ensure 0 <= orientation < 360
  while azimuth < 0
    azimuth += 360
  end
  while azimuth >= 360
    azimuth -= 360
  end
  return azimuth
end

def hpxml_to_hescore_fuel(fuel_type)
  return { 'electricity' => 'electric',
           'natural gas' => 'natural_gas',
           'fuel oil' => 'fuel_oil',
           'propane' => 'lpg' }[fuel_type]
end

def get_foundation_details(orig_details)
  # Returns a hash of foundation_type => area
  fnd_types = {}
  orig_details.elements.each("Enclosure/Foundations/Foundation") do |orig_foundation|
    fnd_adjacent = get_foundation_adjacent(orig_foundation)
    framefloor_id = HPXML.get_idref(orig_foundation, "AttachedToFrameFloor")
    if not framefloor_id.nil?
      framefloor = orig_details.elements["Enclosure/FrameFloors/FrameFloor[SystemIdentifier[@id='#{framefloor_id}']]"]
      framefloor_values = HPXML.get_framefloor_values(framefloor: framefloor)
      fnd_area = framefloor_values[:area]
    else
      slab_id = HPXML.get_idref(orig_foundation, "AttachedToSlab")
      slab = orig_details.elements["Enclosure/Slabs/Slab[SystemIdentifier[@id='#{slab_id}']]"]
      slab_values = HPXML.get_slab_values(slab: slab)
      fnd_area = slab_values[:area]
    end
    fnd_types[fnd_adjacent] = fnd_area
  end
  return fnd_types
end

def get_ducts_details(orig_details)
  # Returns a list of [hvac_frac, duct_frac, duct_location]
  ducts = []
  orig_details.elements.each("Systems/HVAC/HVACDistribution") do |orig_dist|
    dist_values = HPXML.get_hvac_distribution_values(hvac_distribution: orig_dist)
    hvac_frac = get_hvac_fraction(orig_details, dist_values[:id])

    orig_dist.elements.each("DistributionSystemType/AirDistribution/Ducts") do |orig_duct|
      duct_values = HPXML.get_ducts_values(ducts: orig_duct)
      ducts << [hvac_frac, duct_values[:duct_fraction_area], duct_values[:duct_location]]
    end
  end
  return ducts
end

def get_hvac_fraction(orig_details, dist_id)
  orig_details.elements.each("Systems/HVAC/HVACPlant/HeatingSystem") do |orig_heating|
    heating_values = HPXML.get_heating_system_values(heating_system: orig_heating)
    next unless heating_values[:distribution_system_idref] == dist_id

    return heating_values[:fraction_heat_load_served]
  end
  orig_details.elements.each("Systems/HVAC/HVACPlant/CoolingSystem") do |orig_cooling|
    cooling_values = HPXML.get_cooling_system_values(cooling_system: orig_cooling)
    next unless cooling_values[:distribution_system_idref] == dist_id

    return cooling_values[:fraction_cool_load_served]
  end
  orig_details.elements.each("Systems/HVAC/HVACPlant/HeatPump") do |orig_hp|
    hp_values = HPXML.get_heat_pump_values(heat_pump: orig_hp)
    next unless hp_values[:distribution_system_idref] == dist_id

    return hp_values[:fraction_cool_load_served]
  end
  return nil
end

def get_attic_adjacent(attic)
  attic_adjacent = nil
  if XMLHelper.has_element(attic, "AtticType/Attic[Vented='false']")
    attic_adjacent = "attic - unvented"
  elsif XMLHelper.has_element(attic, "AtticType/Attic[Vented='true']")
    attic_adjacent = "attic - vented"
  elsif XMLHelper.has_element(attic, "AtticType/Attic[Conditioned='true']")
    attic_adjacent = "living space"
  elsif XMLHelper.has_element(attic, "AtticType/FlatRoof")
    attic_adjacent = "living space"
  elsif XMLHelper.has_element(attic, "AtticType/CathedralCeiling")
    attic_adjacent = "living space"
  else
    fail "Unexpected attic type."
  end
  return attic_adjacent
end

def get_foundation_adjacent(foundation)
  foundation_adjacent = nil
  if XMLHelper.has_element(foundation, "FoundationType/SlabOnGrade")
    foundation_adjacent = "living space"
  elsif XMLHelper.has_element(foundation, "FoundationType/Basement[Conditioned='false']")
    foundation_adjacent = "basement - unconditioned"
  elsif XMLHelper.has_element(foundation, "FoundationType/Basement[Conditioned='true']")
    foundation_adjacent = "basement - conditioned"
  elsif XMLHelper.has_element(foundation, "FoundationType/Crawlspace[Vented='false']")
    foundation_adjacent = "crawlspace - unvented"
  elsif XMLHelper.has_element(foundation, "FoundationType/Crawlspace[Vented='true']")
    foundation_adjacent = "crawlspace - vented"
  else
    fail "Unexpected foundation type."
  end
  return foundation_adjacent
end
