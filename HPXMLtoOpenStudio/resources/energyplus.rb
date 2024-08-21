# frozen_string_literal: true

# Collection of methods related to the EnergyPlus simulation.
module EPlus
  # Constants
  BoundaryConditionAdiabatic = 'Adiabatic'
  BoundaryConditionCoefficients = 'OtherSideCoefficients'
  BoundaryConditionFoundation = 'Foundation'
  BoundaryConditionGround = 'Ground'
  BoundaryConditionOutdoors = 'Outdoors'
  BoundaryConditionSurface = 'Surface'
  EMSActuatorElectricEquipmentPower = 'ElectricEquipment', 'Electricity Rate'
  EMSActuatorOtherEquipmentPower = 'OtherEquipment', 'Power Level'
  EMSActuatorPumpMassFlowRate = 'Pump', 'Pump Mass Flow Rate'
  EMSActuatorPumpPressureRise = 'Pump', 'Pump Pressure Rise'
  EMSActuatorFanPressureRise = 'Fan', 'Fan Pressure Rise'
  EMSActuatorFanTotalEfficiency = 'Fan', 'Fan Total Efficiency'
  EMSActuatorCurveResult = 'Curve', 'Curve Result'
  EMSActuatorUnitarySystemCoilSpeedLevel = 'Coil Speed Control', 'Unitary System DX Coil Speed Value'
  EMSActuatorScheduleConstantValue = 'Schedule:Constant', 'Schedule Value'
  EMSActuatorScheduleYearValue = 'Schedule:Year', 'Schedule Value'
  EMSActuatorScheduleFileValue = 'Schedule:File', 'Schedule Value'
  EMSActuatorZoneInfiltrationFlowRate = 'Zone Infiltration', 'Air Exchange Flow Rate'
  EMSActuatorZoneMixingFlowRate = 'ZoneMixing', 'Air Exchange Flow Rate'
  EMSIntVarFanMFR = 'Fan Maximum Mass Flow Rate'
  EMSIntVarPumpMFR = 'Pump Maximum Mass Flow Rate'
  FluidPropyleneGlycol = 'PropyleneGlycol'
  FluidWater = 'Water'
  FuelTypeCoal = 'Coal'
  FuelTypeElectricity = 'Electricity'
  FuelTypeNaturalGas = 'NaturalGas'
  FuelTypeNone = 'None'
  FuelTypeOil = 'FuelOilNo2'
  FuelTypePropane = 'Propane'
  FuelTypeWoodCord = 'OtherFuel1'
  FuelTypeWoodPellets = 'OtherFuel2'
  ScheduleTypeLimitsFraction = 'Fractional'
  ScheduleTypeLimitsOnOff = 'OnOff'
  ScheduleTypeLimitsTemperature = 'Temperature'
  SubSurfaceTypeDoor = 'Door'
  SubSurfaceTypeWindow = 'FixedWindow'
  SurfaceSunExposureNo = 'NoSun'
  SurfaceSunExposureYes = 'SunExposed'
  SurfaceTypeFloor = 'Floor'
  SurfaceTypeRoofCeiling = 'RoofCeiling'
  SurfaceTypeWall = 'Wall'
  SurfaceWindExposureNo = 'NoWind'
  SurfaceWindExposureYes = 'WindExposed'

  # Returns the fuel type used in the EnergyPlus simulation that the HPXML fuel type
  # maps to.
  #
  # @param hpxml_fuel [String] HPXML fuel type (HPXML::FuelTypeXXX)
  # @return [String] EnergyPlus fuel type (EPlus::FuelTypeXXX)
  def self.fuel_type(hpxml_fuel)
    # Name of fuel used as inputs to E+ objects
    if [HPXML::FuelTypeElectricity].include? hpxml_fuel
      return FuelTypeElectricity
    elsif [HPXML::FuelTypeNaturalGas].include? hpxml_fuel
      return FuelTypeNaturalGas
    elsif [HPXML::FuelTypeOil,
           HPXML::FuelTypeOil1,
           HPXML::FuelTypeOil2,
           HPXML::FuelTypeOil4,
           HPXML::FuelTypeOil5or6,
           HPXML::FuelTypeDiesel,
           HPXML::FuelTypeKerosene].include? hpxml_fuel
      return FuelTypeOil
    elsif [HPXML::FuelTypePropane].include? hpxml_fuel
      return FuelTypePropane
    elsif [HPXML::FuelTypeWoodCord].include? hpxml_fuel
      return FuelTypeWoodCord
    elsif [HPXML::FuelTypeWoodPellets].include? hpxml_fuel
      return FuelTypeWoodPellets
    elsif [HPXML::FuelTypeCoal,
           HPXML::FuelTypeCoalAnthracite,
           HPXML::FuelTypeCoalBituminous,
           HPXML::FuelTypeCoke].include? hpxml_fuel
      return FuelTypeCoal
    else
      fail "Unexpected HPXML fuel '#{hpxml_fuel}'."
    end
  end
end
