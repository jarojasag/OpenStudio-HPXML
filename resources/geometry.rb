require_relative "constants"
require_relative "unit_conversions"
require_relative "util"

class Geometry
  def self.get_abs_azimuth(azimuth_type, relative_azimuth, building_orientation, offset = 180.0)
    azimuth = nil
    if azimuth_type == Constants.CoordRelative
      azimuth = relative_azimuth + building_orientation + offset
    elsif azimuth_type == Constants.CoordAbsolute
      azimuth = relative_azimuth + offset
    end

    # Ensure azimuth is >=0 and <=360
    while azimuth < 0.0
      azimuth += 360.0
    end

    while azimuth >= 360.0
      azimuth -= 360.0
    end

    return azimuth
  end

  def self.get_abs_tilt(tilt_type, relative_tilt, roof_tilt, latitude)
    if tilt_type == Constants.TiltPitch
      return relative_tilt + roof_tilt
    elsif tilt_type == Constants.TiltLatitude
      return relative_tilt + latitude
    elsif tilt_type == Constants.CoordAbsolute
      return relative_tilt
    end
  end

  def self.initialize_transformation_matrix(m)
    m[0, 0] = 1
    m[1, 1] = 1
    m[2, 2] = 1
    m[3, 3] = 1
    return m
  end

  def self.get_surface_dimensions(surface)
    least_x = 9e99
    greatest_x = -9e99
    least_y = 9e99
    greatest_y = -9e99
    least_z = 9e99
    greatest_z = -9e99
    surface.vertices.each do |vertex|
      least_x = [vertex.x, least_x].min
      greatest_x = [vertex.x, greatest_x].max
      least_y = [vertex.y, least_y].min
      greatest_y = [vertex.y, greatest_y].max
      least_z = [vertex.z, least_z].min
      greatest_z = [vertex.z, greatest_z].max
    end
    l = greatest_x - least_x
    w = greatest_y - least_y
    h = greatest_z - least_z
    return l, w, h
  end

  def self.get_building_stories(spaces)
    space_min_zs = []
    spaces.each do |space|
      next if not self.space_is_finished(space)

      surfaces_min_zs = []
      space.surfaces.each do |surface|
        zvalues = self.getSurfaceZValues([surface])
        surfaces_min_zs << zvalues.min + UnitConversions.convert(space.zOrigin, "m", "ft")
      end
      space_min_zs << surfaces_min_zs.min
    end
    return space_min_zs.uniq.length
  end

  def self.get_above_grade_building_stories(spaces)
    space_min_zs = []
    spaces.each do |space|
      next if not self.space_is_finished(space)
      next if not self.space_is_above_grade(space)

      surfaces_min_zs = []
      space.surfaces.each do |surface|
        zvalues = self.getSurfaceZValues([surface])
        surfaces_min_zs << zvalues.min + UnitConversions.convert(space.zOrigin, "m", "ft")
      end
      space_min_zs << surfaces_min_zs.min
    end
    return space_min_zs.uniq.length
  end

  def self.make_polygon(*pts)
    p = OpenStudio::Point3dVector.new
    pts.each do |pt|
      p << pt
    end
    return p
  end

  def self.get_building_units(model, runner = nil)
    if model.getSpaces.size == 0
      if !runner.nil?
        runner.registerError("No building geometry has been defined.")
      end
      return nil
    end

    return_units = []
    model.getBuildingUnits.each do |unit|
      # Remove any units from list that have no associated spaces or are not residential
      next if not (unit.spaces.size > 0 and unit.buildingUnitType == Constants.BuildingUnitTypeResidential)

      return_units << unit
    end

    return return_units
  end

  def self.get_unit_beds_baths(model, unit, runner = nil)
    # Returns a list with #beds, #baths, a list of spaces, and the unit name
    nbeds = unit.additionalProperties.getFeatureAsInteger(Constants.BuildingUnitFeatureNumBedrooms)
    nbaths = unit.additionalProperties.getFeatureAsDouble(Constants.BuildingUnitFeatureNumBathrooms)
    if not (nbeds.is_initialized or nbaths.is_initialized)
      if !runner.nil?
        runner.registerError("Could not determine number of bedrooms or bathrooms.")
      end
      return [nil, nil]
    else
      nbeds = nbeds.get.to_f
      nbaths = nbaths.get
    end
    return [nbeds, nbaths]
  end

  def self.get_unit_adjacent_common_spaces(unit)
    # Returns a list of spaces adjacent to the unit that are not assigned
    # to a building unit.
    spaces = []

    unit.spaces.each do |space|
      space.surfaces.each do |surface|
        next if not surface.adjacentSurface.is_initialized

        adjacent_surface = surface.adjacentSurface.get
        next if not adjacent_surface.space.is_initialized

        adjacent_space = adjacent_surface.space.get
        next if adjacent_space.buildingUnit.is_initialized

        spaces << adjacent_space
      end
    end

    return spaces.uniq
  end

  def self.get_floor_area_from_spaces(spaces, runner = nil)
    floor_area = 0
    spaces.each do |space|
      floor_area += UnitConversions.convert(space.floorArea, "m^2", "ft^2")
    end
    if floor_area == 0 and not runner.nil?
      runner.registerError("Could not find any floor area.")
      return nil
    end
    return floor_area
  end

  def self.get_zone_volume(zone, runner = nil)
    if zone.isVolumeAutocalculated or not zone.volume.is_initialized
      # Calculate volume from spaces
      volume = 0
      zone.spaces.each do |space|
        volume += UnitConversions.convert(space.volume, "m^3", "ft^3")
      end
    else
      volume = UnitConversions.convert(zone.volume.get, "m^3", "ft^3")
    end
    if volume <= 0 and not runner.nil?
      runner.registerError("Could not find any volume.")
      return nil
    end
    return volume
  end

  def self.get_finished_floor_area_from_spaces(spaces, runner = nil)
    floor_area = 0
    spaces.each do |space|
      next if not self.space_is_finished(space)

      floor_area += UnitConversions.convert(space.floorArea, "m^2", "ft^2")
    end
    if floor_area == 0 and not runner.nil?
      runner.registerError("Could not find any finished floor area.")
      return nil
    end
    return floor_area
  end

  def self.get_above_grade_finished_floor_area_from_spaces(spaces, runner = nil)
    floor_area = 0
    spaces.each do |space|
      next if not (self.space_is_finished(space) and self.space_is_above_grade(space))

      floor_area += UnitConversions.convert(space.floorArea, "m^2", "ft^2")
    end
    if floor_area == 0 and not runner.nil?
      runner.registerError("Could not find any above-grade finished floor area.")
      return nil
    end
    return floor_area
  end

  def self.get_above_grade_finished_volume(model, runner = nil)
    volume = 0
    model.getThermalZones.each do |zone|
      next if not (self.zone_is_finished(zone) and self.zone_is_above_grade(zone))

      volume += self.get_zone_volume(zone, runner)
    end
    if volume == 0 and not runner.nil?
      runner.registerError("Could not find any above-grade finished volume.")
      return nil
    end
    return volume
  end

  def self.get_window_area_from_spaces(spaces)
    window_area = 0
    spaces.each do |space|
      space.surfaces.each do |surface|
        surface.subSurfaces.each do |subsurface|
          next if subsurface.subSurfaceType.downcase != "fixedwindow"

          window_area += UnitConversions.convert(subsurface.grossArea, "m^2", "ft^2")
        end
      end
    end
    return window_area
  end

  def self.space_height(space)
    return Geometry.get_height_of_spaces([space])
  end

  # Calculates space heights as the max z coordinate minus the min z coordinate
  def self.get_height_of_spaces(spaces)
    minzs = []
    maxzs = []
    spaces.each do |space|
      zvalues = self.getSurfaceZValues(space.surfaces)
      minzs << zvalues.min + UnitConversions.convert(space.zOrigin, "m", "ft")
      maxzs << zvalues.max + UnitConversions.convert(space.zOrigin, "m", "ft")
    end
    return maxzs.max - minzs.min
  end

  # Calculates the surface height as the max z coordinate minus the min z coordinate
  def self.surface_height(surface)
    zvalues = self.getSurfaceZValues([surface])
    minz = zvalues.min
    maxz = zvalues.max
    return maxz - minz
  end

  def self.zone_is_finished(zone)
    zone.spaces.each do |space|
      unless self.space_is_finished(space)
        return false
      end
    end
  end

  # Returns true if all spaces in zone are fully above grade
  def self.zone_is_above_grade(zone)
    spaces_are_above_grade = []
    zone.spaces.each do |space|
      spaces_are_above_grade << self.space_is_above_grade(space)
    end
    if spaces_are_above_grade.all?
      return true
    end

    return false
  end

  # Returns true if all spaces in zone are either fully or partially below grade
  def self.zone_is_below_grade(zone)
    return !self.zone_is_above_grade(zone)
  end

  def self.get_finished_above_and_below_grade_zones(thermal_zones)
    finished_living_zones = []
    finished_basement_zones = []
    thermal_zones.each do |thermal_zone|
      next unless self.zone_is_finished(thermal_zone)

      if self.zone_is_above_grade(thermal_zone)
        finished_living_zones << thermal_zone
      elsif self.zone_is_below_grade(thermal_zone)
        finished_basement_zones << thermal_zone
      end
    end
    return finished_living_zones, finished_basement_zones
  end

  def self.get_thermal_zones_from_spaces(spaces)
    thermal_zones = []
    spaces.each do |space|
      next unless space.thermalZone.is_initialized

      unless thermal_zones.include? space.thermalZone.get
        thermal_zones << space.thermalZone.get
      end
    end
    return thermal_zones
  end

  def self.space_is_unfinished(space)
    return !self.space_is_finished(space)
  end

  def self.space_is_finished(space)
    unless space.isPlenum
      if space.spaceType.is_initialized
        if space.spaceType.get.standardsSpaceType.is_initialized
          return self.is_living_space_type(space.spaceType.get.standardsSpaceType.get)
        end
      end
    end
    return false
  end

  def self.is_living_space_type(space_type)
    if [Constants.SpaceTypeLiving, Constants.SpaceTypeFinishedBasement].include? space_type
      return true
    end

    return false
  end

  # Returns true if space is fully above grade
  def self.space_is_above_grade(space)
    return !self.space_is_below_grade(space)
  end

  # Returns true if space is either fully or partially below grade
  def self.space_is_below_grade(space)
    space.surfaces.each do |surface|
      next if surface.surfaceType.downcase != "wall"
      if surface.outsideBoundaryCondition.downcase == "foundation"
        return true
      end
    end
    return false
  end

  def self.get_space_from_location(unit, location, location_hierarchy)
    spaces = unit.spaces + self.get_unit_adjacent_common_spaces(unit)
    if location == Constants.Auto
      location_hierarchy.each do |space_type|
        spaces.each do |space|
          next if not self.space_is_of_type(space, space_type)

          return space
        end
      end
    else
      spaces.each do |space|
        next if not space.spaceType.is_initialized
        next if not space.spaceType.get.standardsSpaceType.is_initialized
        next if space.spaceType.get.standardsSpaceType.get != location

        return space
      end
    end
    return nil
  end

  # Return an array of x values for surfaces passed in. The values will be relative to the parent origin. This was intended for spaces.
  def self.getSurfaceXValues(surfaceArray)
    xValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        xValueArray << UnitConversions.convert(vertex.x, "m", "ft")
      end
    end
    return xValueArray
  end

  # Return an array of y values for surfaces passed in. The values will be relative to the parent origin. This was intended for spaces.
  def self.getSurfaceYValues(surfaceArray)
    yValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        yValueArray << UnitConversions.convert(vertex.y, "m", "ft")
      end
    end
    return yValueArray
  end

  # Return an array of z values for surfaces passed in. The values will be relative to the parent origin. This was intended for spaces.
  def self.getSurfaceZValues(surfaceArray)
    zValueArray = []
    surfaceArray.each do |surface|
      surface.vertices.each do |vertex|
        zValueArray << UnitConversions.convert(vertex.z, "m", "ft")
      end
    end
    return zValueArray
  end

  def self.get_z_origin_for_zone(zone)
    z_origins = []
    zone.spaces.each do |space|
      z_origins << UnitConversions.convert(space.zOrigin, "m", "ft")
    end
    return z_origins.min
  end

  # Takes in a list of spaces and returns the total above grade wall area
  def self.calculate_above_grade_wall_area(spaces)
    wall_area = 0
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != "wall"
        next if surface.outsideBoundaryCondition.downcase == "foundation"

        wall_area += UnitConversions.convert(surface.grossArea, "m^2", "ft^2")
      end
    end
    return wall_area
  end

  def self.calculate_above_grade_exterior_wall_area(spaces)
    wall_area = 0
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if surface.surfaceType.downcase != "wall"
        next if surface.outsideBoundaryCondition.downcase != "outdoors"
        next if surface.outsideBoundaryCondition.downcase == "foundation"
        next unless self.space_is_finished(surface.space.get)

        wall_area += UnitConversions.convert(surface.grossArea, "m^2", "ft^2")
      end
    end
    return wall_area
  end

  def self.get_roof_pitch(surfaces)
    tilts = []
    surfaces.each do |surface|
      next if surface.surfaceType.downcase != "roofceiling"
      next if surface.outsideBoundaryCondition.downcase != "outdoors" and surface.outsideBoundaryCondition.downcase != "adiabatic"

      tilts << surface.tilt
    end
    return UnitConversions.convert(tilts.max, "rad", "deg")
  end

  # Checks if the surface is between finished and unfinished space
  def self.is_interzonal_surface(surface)
    if surface.outsideBoundaryCondition.downcase != "surface" or not surface.space.is_initialized or not surface.adjacentSurface.is_initialized
      return false
    end

    adjacent_surface = surface.adjacentSurface.get
    if not adjacent_surface.space.is_initialized
      return false
    end
    if self.space_is_finished(surface.space.get) == self.space_is_finished(adjacent_surface.space.get)
      return false
    end

    return true
  end

  def self.is_living(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeLiving)
  end

  def self.is_pier_beam(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypePierBeam)
  end

  def self.is_crawl(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeCrawl)
  end

  def self.is_finished_basement(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeFinishedBasement)
  end

  def self.is_unfinished_basement(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeUnfinishedBasement)
  end

  def self.is_unfinished_attic(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeUnfinishedAttic)
  end

  def self.is_garage(space_or_zone)
    return self.space_or_zone_is_of_type(space_or_zone, Constants.SpaceTypeGarage)
  end

  def self.space_or_zone_is_of_type(space_or_zone, space_type)
    if space_or_zone.is_a? OpenStudio::Model::Space
      return self.space_is_of_type(space_or_zone, space_type)
    elsif space_or_zone.is_a? OpenStudio::Model::ThermalZone
      return self.zone_is_of_type(space_or_zone, space_type)
    end
  end

  def self.space_is_of_type(space, space_type)
    unless space.isPlenum
      if space.spaceType.is_initialized
        if space.spaceType.get.standardsSpaceType.is_initialized
          return true if space.spaceType.get.standardsSpaceType.get == space_type
        end
      end
    end
    return false
  end

  def self.zone_is_of_type(zone, space_type)
    zone.spaces.each do |space|
      return self.space_is_of_type(space, space_type)
    end
  end

  def self.get_finished_spaces(spaces)
    finished_spaces = []
    spaces.each do |space|
      next if self.space_is_unfinished(space)

      finished_spaces << space
    end
    return finished_spaces
  end

  def self.get_unfinished_basement_spaces(spaces)
    unfinished_basement_spaces = []
    spaces.each do |space|
      next if not self.is_unfinished_basement(space)

      unfinished_basement_spaces << space
    end
    return unfinished_basement_spaces
  end

  def self.get_garage_spaces(spaces)
    garage_spaces = []
    spaces.each do |space|
      next if not self.is_garage(space)

      garage_spaces << space
    end
    return garage_spaces
  end

  def self.get_facade_for_surface(surface)
    tol = 0.001
    n = surface.outwardNormal
    facade = nil
    if (n.z).abs < tol
      if (n.x).abs < tol and (n.y + 1).abs < tol
        facade = Constants.FacadeFront
      elsif (n.x - 1).abs < tol and (n.y).abs < tol
        facade = Constants.FacadeRight
      elsif (n.x).abs < tol and (n.y - 1).abs < tol
        facade = Constants.FacadeBack
      elsif (n.x + 1).abs < tol and (n.y).abs < tol
        facade = Constants.FacadeLeft
      end
    else
      if (n.x).abs < tol and n.y < 0
        facade = Constants.FacadeFront
      elsif n.x > 0 and (n.y).abs < tol
        facade = Constants.FacadeRight
      elsif (n.x).abs < tol and n.y > 0
        facade = Constants.FacadeBack
      elsif n.x < 0 and (n.y).abs < tol
        facade = Constants.FacadeLeft
      end
    end
    return facade
  end

  def self.get_surface_length(surface)
    xvalues = self.getSurfaceXValues([surface])
    yvalues = self.getSurfaceYValues([surface])
    xrange = xvalues.max - xvalues.min
    yrange = yvalues.max - yvalues.min
    if xrange > yrange
      return xrange
    end

    return yrange
  end

  def self.get_surface_height(surface)
    zvalues = self.getSurfaceZValues([surface])
    zrange = zvalues.max - zvalues.min
    return zrange
  end

  def self.get_closest_neighbor_distance(model)
    house_points = []
    neighbor_points = []
    model.getSurfaces.each do |surface|
      next unless surface.surfaceType.downcase == "wall"

      surface.vertices.each do |vertex|
        house_points << OpenStudio::Point3d.new(vertex)
      end
    end
    model.getShadingSurfaces.each do |shading_surface|
      next unless shading_surface.name.to_s.downcase.include? "neighbor"

      shading_surface.vertices.each do |vertex|
        neighbor_points << OpenStudio::Point3d.new(vertex)
      end
    end
    neighbor_offsets = []
    house_points.each do |house_point|
      neighbor_points.each do |neighbor_point|
        neighbor_offsets << OpenStudio::getDistance(house_point, neighbor_point)
      end
    end
    if neighbor_offsets.empty?
      return 0
    end

    return UnitConversions.convert(neighbor_offsets.min, "m", "ft")
  end

  def self.get_spaces_above_grade_exterior_walls(spaces)
    above_grade_exterior_walls = []
    spaces.each do |space|
      next if not Geometry.space_is_finished(space)
      next if not Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if above_grade_exterior_walls.include?(surface)
        next if surface.surfaceType.downcase != "wall"
        next if surface.outsideBoundaryCondition.downcase != "outdoors"

        above_grade_exterior_walls << surface
      end
    end
    return above_grade_exterior_walls
  end

  def self.get_spaces_above_grade_exterior_floors(spaces)
    above_grade_exterior_floors = []
    spaces.each do |space|
      next if not Geometry.space_is_finished(space)
      next if not Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if above_grade_exterior_floors.include?(surface)
        next if surface.surfaceType.downcase != "floor"
        next if surface.outsideBoundaryCondition.downcase != "outdoors"

        above_grade_exterior_floors << surface
      end
    end
    return above_grade_exterior_floors
  end

  def self.get_spaces_above_grade_ground_floors(spaces)
    above_grade_ground_floors = []
    spaces.each do |space|
      next if not Geometry.space_is_finished(space)
      next if not Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if above_grade_ground_floors.include?(surface)
        next if surface.surfaceType.downcase != "floor"
        next if surface.outsideBoundaryCondition.downcase != "foundation"

        above_grade_ground_floors << surface
      end
    end
    return above_grade_ground_floors
  end

  def self.get_spaces_above_grade_exterior_roofs(spaces)
    above_grade_exterior_roofs = []
    spaces.each do |space|
      next if not Geometry.space_is_finished(space)
      next if not Geometry.space_is_above_grade(space)

      space.surfaces.each do |surface|
        next if above_grade_exterior_roofs.include?(surface)
        next if surface.surfaceType.downcase != "roofceiling"
        next if surface.outsideBoundaryCondition.downcase != "outdoors"

        above_grade_exterior_roofs << surface
      end
    end
    return above_grade_exterior_roofs
  end

  def self.get_spaces_interzonal_walls(spaces)
    interzonal_walls = []
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if interzonal_walls.include?(surface)
        next if surface.surfaceType.downcase != "wall"
        next if not self.is_interzonal_surface(surface)

        interzonal_walls << surface
      end
    end
    return interzonal_walls
  end

  def self.get_spaces_interzonal_floors_and_ceilings(spaces)
    interzonal_floors = []
    spaces.each do |space|
      space.surfaces.each do |surface|
        next if interzonal_floors.include?(surface)
        next if surface.surfaceType.downcase != "floor" and surface.surfaceType.downcase != "roofceiling"
        next if not self.is_interzonal_surface(surface)

        interzonal_floors << surface
      end
    end
    return interzonal_floors
  end

  def self.get_spaces_below_grade_exterior_walls(spaces)
    below_grade_exterior_walls = []
    spaces.each do |space|
      next if not Geometry.space_is_finished(space)
      next if not Geometry.space_is_below_grade(space)

      space.surfaces.each do |surface|
        next if below_grade_exterior_walls.include?(surface)
        next if surface.surfaceType.downcase != "wall"
        next if surface.outsideBoundaryCondition.downcase != "foundation"

        below_grade_exterior_walls << surface
      end
    end
    return below_grade_exterior_walls
  end

  def self.get_spaces_below_grade_exterior_floors(spaces)
    below_grade_exterior_floors = []
    spaces.each do |space|
      next if not Geometry.space_is_finished(space)
      next if not Geometry.space_is_below_grade(space)

      space.surfaces.each do |surface|
        next if below_grade_exterior_floors.include?(surface)
        next if surface.surfaceType.downcase != "floor"
        next if surface.outsideBoundaryCondition.downcase != "foundation"

        below_grade_exterior_floors << surface
      end
    end
    return below_grade_exterior_floors
  end

  def self.process_beds_and_baths(model, runner, num_br, num_ba)
    # Error checking
    if not num_br.all? { |x| MathTools.valid_float?(x) }
      runner.registerError("Number of bedrooms must be a numerical value.")
      return false
    else
      num_br = num_br.map(&:to_f)
    end
    if not num_ba.all? { |x| MathTools.valid_float?(x) }
      runner.registerError("Number of bathrooms must be a numerical value.")
      return false
    else
      num_ba = num_ba.map(&:to_f)
    end
    if num_br.any? { |x| x <= 0 or x % 1 != 0 }
      runner.registerError("Number of bedrooms must be a positive integer.")
      return false
    end
    if num_ba.any? { |x| x <= 0 or x % 0.25 != 0 }
      runner.registerError("Number of bathrooms must be a positive multiple of 0.25.")
      return false
    end
    if num_br.length > 1 and num_ba.length > 1 and num_br.length != num_ba.length
      runner.registerError("Number of bedroom elements specified inconsistent with number of bathroom elements specified.")
      return false
    end

    # Get building units
    units = self.get_building_units(model, runner)
    if units.nil?
      return false
    end

    # error checking
    if num_br.length > 1 and num_br.length != units.size
      runner.registerError("Number of bedroom elements specified inconsistent with number of multifamily units defined in the model.")
      return false
    end
    if num_ba.length > 1 and num_ba.length != units.size
      runner.registerError("Number of bathroom elements specified inconsistent with number of multifamily units defined in the model.")
      return false
    end

    if units.size > 1 and num_br.length == 1
      if num_br.length == 1
        num_br = Array.new(units.size, num_br[0])
      end
      if num_ba.length == 1
        num_ba = Array.new(units.size, num_ba[0])
      end
    end

    # Update number of bedrooms/bathrooms
    total_num_br = 0
    total_num_ba = 0
    units.each_with_index do |unit, unit_index|
      num_br[unit_index] = num_br[unit_index].to_i
      num_ba[unit_index] = num_ba[unit_index].to_f

      unit.additionalProperties.setFeature(Constants.BuildingUnitFeatureNumBedrooms, num_br[unit_index])
      unit.additionalProperties.setFeature(Constants.BuildingUnitFeatureNumBathrooms, num_ba[unit_index])

      if units.size > 1
        runner.registerInfo("Unit '#{unit_index}' has been assigned #{num_br[unit_index].to_s} bedroom(s) and #{num_ba[unit_index].round(2).to_s} bathroom(s).")
      end

      total_num_br += num_br[unit_index]
      total_num_ba += num_ba[unit_index]
    end

    runner.registerInfo("The building has been assigned #{total_num_br.to_s} bedroom(s) and #{total_num_ba.round(2).to_s} bathroom(s) across #{units.size} unit(s).")
    return true
  end

  def self.process_occupants(model, runner, num_occ, occ_gain, sens_frac, lat_frac, weekday_sch, weekend_sch, monthly_sch)
    num_occ = num_occ.split(",").map(&:strip)

    # Error checking
    if occ_gain < 0
      runner.registerError("Internal gains cannot be negative.")
      return false
    end

    if sens_frac < 0 or sens_frac > 1
      runner.registerError("Sensible fraction must be greater than or equal to 0 and less than or equal to 1.")
      return false
    end
    if lat_frac < 0 or lat_frac > 1
      runner.registerError("Latent fraction must be greater than or equal to 0 and less than or equal to 1.")
      return false
    end
    if lat_frac + sens_frac > 1
      runner.registerError("Sum of sensible and latent fractions must be less than or equal to 1.")
      return false
    end

    # Get building units
    units = self.get_building_units(model, runner)
    if units.nil?
      return false
    end

    # Error checking
    if num_occ.length > 1 and num_occ.length != units.size
      runner.registerError("Number of occupant elements specified inconsistent with number of multifamily units defined in the model.")
      return false
    end

    if units.size > 1 and num_occ.length == 1
      num_occ = Array.new(units.size, num_occ[0])
    end

    activity_per_person = UnitConversions.convert(occ_gain, "Btu/hr", "W")

    # Hard-coded convective, radiative, latent, and lost fractions
    occ_lat = lat_frac
    occ_sens = sens_frac
    occ_conv = 0.442 * occ_sens
    occ_rad = 0.558 * occ_sens
    occ_lost = 1 - occ_lat - occ_conv - occ_rad

    # Update number of occupants
    total_num_occ = 0
    people_sch = nil
    activity_sch = nil
    units.each_with_index do |unit, unit_index|
      unit_occ = num_occ[unit_index]

      if unit_occ != Constants.Auto
        if not MathTools.valid_float?(unit_occ)
          runner.registerError("Number of Occupants must be either '#{Constants.Auto}' or a number greater than or equal to 0.")
          return false
        elsif unit_occ.to_f < 0
          runner.registerError("Number of Occupants must be either '#{Constants.Auto}' or a number greater than or equal to 0.")
          return false
        end
      end

      # Get number of beds
      nbeds, nbaths = self.get_unit_beds_baths(model, unit, runner)
      if nbeds.nil?
        return false
      end

      # Calculate number of occupants for this unit
      if unit_occ == Constants.Auto
        if units.size > 1 # multifamily equation
          unit_occ = 0.63 + 0.92 * nbeds
        else # single-family equation
          unit_occ = 0.87 + 0.59 * nbeds
        end
      else
        unit_occ = unit_occ.to_f
      end

      # Get spaces
      ffa_spaces = self.get_finished_spaces(unit.spaces)

      # Get FFA
      ffa = self.get_finished_floor_area_from_spaces(ffa_spaces, runner)

      schedules = {}
      schedules[ffa_spaces] = [weekday_sch, weekend_sch, activity_per_person]

      # Assign occupants to each space of the unit
      schedules.each do |spaces, schedule|
        spaces.each do |space|
          space_obj_name = "#{Constants.ObjectNameOccupants(unit.name.to_s)}|#{space.name.to_s}"

          space_num_occ = unit_occ * UnitConversions.convert(space.floorArea, "m^2", "ft^2") / ffa

          if space_num_occ > 0

            if people_sch.nil?
              # Create schedule
              people_sch = MonthWeekdayWeekendSchedule.new(model, runner, Constants.ObjectNameOccupants + " schedule", schedule[0], schedule[1], monthly_sch)
              if not people_sch.validated?
                return false
              end
            end

            if activity_sch.nil?
              # Create schedule
              activity_sch = OpenStudio::Model::ScheduleRuleset.new(model, schedule[2])
            end

            # Add people definition for the occ
            occ_def = OpenStudio::Model::PeopleDefinition.new(model)
            occ = OpenStudio::Model::People.new(occ_def)
            occ.setName(space_obj_name)
            occ.setSpace(space)
            occ_def.setName(space_obj_name)
            occ_def.setNumberOfPeopleCalculationMethod("People", 1)
            occ_def.setNumberofPeople(space_num_occ)
            occ_def.setFractionRadiant(occ_rad)
            occ_def.setSensibleHeatFraction(occ_sens)
            occ_def.setMeanRadiantTemperatureCalculationType("ZoneAveraged")
            occ_def.setCarbonDioxideGenerationRate(0)
            occ_def.setEnableASHRAE55ComfortWarnings(false)
            occ.setActivityLevelSchedule(activity_sch)
            occ.setNumberofPeopleSchedule(people_sch.schedule)

            total_num_occ += space_num_occ

            runner.registerInfo("#{unit.name.to_s} has been assigned #{space_num_occ.round(2)} occupant(s) for space '#{space.name}'.")

          end
        end
      end
    end

    runner.registerInfo("The building has been assigned #{total_num_occ.round(2)} occupant(s) across #{units.size} unit(s).")
    return true
  end

  def self.get_occupancy_default_num(nbeds)
    return Float(nbeds)
  end

  def self.get_occupancy_default_values()
    # Table 4.2.2(3). Internal Gains for Reference Homes
    hrs_per_day = 16.5 # hrs/day
    sens_gains = 3716.0 # Btu/person/day
    lat_gains = 2884.0 # Btu/person/day
    tot_gains = sens_gains + lat_gains
    heat_gain = tot_gains / hrs_per_day # Btu/person/hr
    sens = sens_gains / tot_gains
    lat = lat_gains / tot_gains
    return heat_gain, hrs_per_day, sens, lat
  end

  def self.process_neighbors(model, runner, left_neighbor_offset, right_neighbor_offset, back_neighbor_offset, front_neighbor_offset)
    # Error checking
    if left_neighbor_offset < 0 or right_neighbor_offset < 0 or back_neighbor_offset < 0 or front_neighbor_offset < 0
      runner.registerError("Neighbor offsets must be greater than or equal to 0.")
      return false
    end

    surfaces = model.getSurfaces
    if surfaces.size == 0
      runner.registerInfo("No surfaces found to copy for neighboring buildings.")
      return true
    end

    # No neighbor shading surfaces to add? Exit here.
    if [left_neighbor_offset, right_neighbor_offset, back_neighbor_offset, front_neighbor_offset].all? { |offset| offset == 0 }
      runner.registerInfo("No #{Constants.ObjectNameNeighbors} shading surfaces to be added.")
      return true
    end

    # Get x, y, z minima and maxima of wall surfaces
    least_x = 9e99
    greatest_x = -9e99
    least_y = 9e99
    greatest_y = -9e99
    greatest_z = -9e99
    surfaces.each do |surface|
      next unless surface.surfaceType.downcase == "wall"

      space = surface.space.get
      surface.vertices.each do |vertex|
        if vertex.x > greatest_x
          greatest_x = vertex.x
        end
        if vertex.x < least_x
          least_x = vertex.x
        end
        if vertex.y > greatest_y
          greatest_y = vertex.y
        end
        if vertex.y < least_y
          least_y = vertex.y
        end
        if vertex.z + space.zOrigin > greatest_z
          greatest_z = vertex.z + space.zOrigin
        end
      end
    end

    directions = [[Constants.FacadeLeft, left_neighbor_offset], [Constants.FacadeRight, right_neighbor_offset], [Constants.FacadeBack, back_neighbor_offset], [Constants.FacadeFront, front_neighbor_offset]]

    shading_surface_group = OpenStudio::Model::ShadingSurfaceGroup.new(model)
    shading_surface_group.setName(Constants.ObjectNameNeighbors)

    num_added = 0
    directions.each do |facade, neighbor_offset|
      next unless neighbor_offset > 0

      vertices = OpenStudio::Point3dVector.new
      m = Geometry.initialize_transformation_matrix(OpenStudio::Matrix.new(4, 4, 0))
      transformation = OpenStudio::Transformation.new(m)
      if facade == Constants.FacadeLeft
        vertices << OpenStudio::Point3d.new(least_x - neighbor_offset, least_y, 0)
        vertices << OpenStudio::Point3d.new(least_x - neighbor_offset, least_y, greatest_z)
        vertices << OpenStudio::Point3d.new(least_x - neighbor_offset, greatest_y, greatest_z)
        vertices << OpenStudio::Point3d.new(least_x - neighbor_offset, greatest_y, 0)
      elsif facade == Constants.FacadeRight
        vertices << OpenStudio::Point3d.new(greatest_x + neighbor_offset, greatest_y, 0)
        vertices << OpenStudio::Point3d.new(greatest_x + neighbor_offset, greatest_y, greatest_z)
        vertices << OpenStudio::Point3d.new(greatest_x + neighbor_offset, least_y, greatest_z)
        vertices << OpenStudio::Point3d.new(greatest_x + neighbor_offset, least_y, 0)
      elsif facade == Constants.FacadeFront
        vertices << OpenStudio::Point3d.new(greatest_x, least_y - neighbor_offset, 0)
        vertices << OpenStudio::Point3d.new(greatest_x, least_y - neighbor_offset, greatest_z)
        vertices << OpenStudio::Point3d.new(least_x, least_y - neighbor_offset, greatest_z)
        vertices << OpenStudio::Point3d.new(least_x, least_y - neighbor_offset, 0)
      elsif facade == Constants.FacadeBack
        vertices << OpenStudio::Point3d.new(least_x, greatest_y + neighbor_offset, 0)
        vertices << OpenStudio::Point3d.new(least_x, greatest_y + neighbor_offset, greatest_z)
        vertices << OpenStudio::Point3d.new(greatest_x, greatest_y + neighbor_offset, greatest_z)
        vertices << OpenStudio::Point3d.new(greatest_x, greatest_y + neighbor_offset, 0)
      end
      vertices = transformation * vertices
      shading_surface = OpenStudio::Model::ShadingSurface.new(vertices, model)
      shading_surface.setName(Constants.ObjectNameNeighbors(facade))
      shading_surface.setShadingSurfaceGroup(shading_surface_group)
      num_added += 1
    end

    runner.registerInfo("Added #{num_added} #{Constants.ObjectNameNeighbors} shading surfaces.")
    return true
  end
end
