# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'
require_relative '../../BuildResidentialScheduleFile/resources/constants.rb'

class HPXMLtoOpenStudioSchedulesTest < Minitest::Test
  def setup
    @root_path = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
    @sample_files_path = File.join(@root_path, 'workflow', 'sample_files')
    @tmp_hpxml_path = File.join(@sample_files_path, 'tmp.xml')
    @tmp_schedule_file_path = File.join(@sample_files_path, 'tmp.csv')

    @year = 2007
    @tight_tol = 0.005
  end

  def teardown
    File.delete(@tmp_hpxml_path) if File.exist? @tmp_hpxml_path
    File.delete(@tmp_schedule_file_path) if File.exist? @tmp_schedule_file_path
  end

  def sample_files_dir
    return File.join(File.dirname(__FILE__), '..', '..', 'workflow', 'sample_files')
  end

  def get_annual_equivalent_full_load_hrs(model, name)
    (model.getScheduleConstants + model.getScheduleRulesets + model.getScheduleFixedIntervals).each do |schedule|
      next if schedule.name.to_s != name

      return Schedule.annual_equivalent_full_load_hrs(@year, schedule)
    end
    flunk "Could not find schedule '#{name}'."
  end

  def get_available_hrs_ratio(unavailable_month_hrs, mults = '1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1')
    # month_idx => unavailable_hrs
    mults = mults.split(',').map { |i| i.to_f }
    total_unavailable_hrs = 0.0
    unavailable_month_hrs.each do |unavailable_month, unavailable_hrs|
      total_unavailable_hrs += unavailable_hrs * mults[unavailable_month]
    end
    return 1.0 - (total_unavailable_hrs / Constants.NumHoursInYear(@year))
  end

  def test_default_schedules
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))
    model, _hpxml, _hpxml_bldg = _test_measure(args_hash)

    schedule_constants = 11
    schedule_rulesets = 17
    schedule_fixed_intervals = 1
    schedule_files = 0

    assert_equal(schedule_constants, model.getScheduleConstants.size)
    assert_equal(schedule_rulesets, model.getScheduleRulesets.size)
    assert_equal(schedule_fixed_intervals, model.getScheduleFixedIntervals.size)
    assert_equal(schedule_files, model.getScheduleFiles.size)
    assert_equal(model.getSchedules.size, schedule_constants + schedule_rulesets + schedule_fixed_intervals + schedule_files)

    assert_in_epsilon(6020, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameOccupants + ' schedule'), @tight_tol)
    assert_in_epsilon(3321, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingInterior + ' schedule'), @tight_tol)
    assert_in_epsilon(2763, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingExterior + ' schedule'), @tight_tol)
    assert_in_epsilon(6673, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameRefrigerator + ' schedule'), @tight_tol)
    assert_in_epsilon(2224, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameCookingRange + ' schedule'), @tight_tol)
    assert_in_epsilon(2994, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameDishwasher + ' schedule'), @tight_tol)
    assert_in_epsilon(4158, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameClothesWasher + ' schedule'), @tight_tol)
    assert_in_epsilon(4502, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameClothesDryer + ' schedule'), @tight_tol)
    assert_in_epsilon(5468, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMiscPlugLoads + ' schedule'), @tight_tol)
    assert_in_epsilon(2256, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMiscTelevision + ' schedule'), @tight_tol)
    assert_in_epsilon(4204, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameFixtures + ' schedule'), @tight_tol)
    assert_in_epsilon(8760, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMechanicalVentilationHouseFan + ' schedule'), @tight_tol)
  end

  def test_simple_schedules
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-schedules-simple.xml'))
    model, _hpxml, _hpxml_bldg = _test_measure(args_hash)

    schedule_constants = 11
    schedule_rulesets = 17
    schedule_fixed_intervals = 1
    schedule_files = 0

    assert_equal(schedule_constants, model.getScheduleConstants.size)
    assert_equal(schedule_rulesets, model.getScheduleRulesets.size)
    assert_equal(schedule_fixed_intervals, model.getScheduleFixedIntervals.size)
    assert_equal(schedule_files, model.getScheduleFiles.size)
    assert_equal(model.getSchedules.size, schedule_constants + schedule_rulesets + schedule_fixed_intervals + schedule_files)

    assert_in_epsilon(6020, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameOccupants + ' schedule'), @tight_tol)
    assert_in_epsilon(3405, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingInterior + ' schedule'), @tight_tol)
    assert_in_epsilon(2763, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingExterior + ' schedule'), @tight_tol)
    assert_in_epsilon(6673, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameRefrigerator + ' schedule'), @tight_tol)
    assert_in_epsilon(2224, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameCookingRange + ' schedule'), @tight_tol)
    assert_in_epsilon(2994, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameDishwasher + ' schedule'), @tight_tol)
    assert_in_epsilon(4158, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameClothesWasher + ' schedule'), @tight_tol)
    assert_in_epsilon(4502, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameClothesDryer + ' schedule'), @tight_tol)
    assert_in_epsilon(5468, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMiscPlugLoads + ' schedule'), @tight_tol)
    assert_in_epsilon(2956, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMiscTelevision + ' schedule'), @tight_tol)
    assert_in_epsilon(4204, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameFixtures + ' schedule'), @tight_tol)
    assert_in_epsilon(8760, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMechanicalVentilationHouseFan + ' schedule'), @tight_tol)
  end

  def test_simple_vacancy_schedules
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-schedules-simple-vacancy.xml'))
    model, _hpxml, _hpxml_bldg = _test_measure(args_hash)

    unavailable_month_hrs = { 0 => 31.0 * 24.0, 11 => 31.0 * 24.0 }

    assert_in_epsilon(6020 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.OccupantsMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameOccupants + ' schedule'), @tight_tol)
    assert_in_epsilon(3405 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.LightingInteriorMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingInterior + ' schedule'), @tight_tol)
    assert_in_epsilon(2763 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.LightingExteriorMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingExterior + ' schedule'), @tight_tol)
    assert_in_epsilon(6673, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameRefrigerator + ' schedule'), @tight_tol)
    assert_in_epsilon(2224 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.CookingRangeMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameCookingRange + ' schedule'), @tight_tol)
    assert_in_epsilon(2994 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.DishwasherMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameDishwasher + ' schedule'), @tight_tol)
    assert_in_epsilon(4158 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.ClothesWasherMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameClothesWasher + ' schedule'), @tight_tol)
    assert_in_epsilon(4502 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.ClothesDryerMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameClothesDryer + ' schedule'), @tight_tol)
    assert_in_epsilon(5468 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.PlugLoadsOtherMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMiscPlugLoads + ' schedule'), @tight_tol)
    assert_in_epsilon(2956 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.PlugLoadsTVMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMiscTelevision + ' schedule'), @tight_tol)
    assert_in_epsilon(4204 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.FixturesMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameFixtures + ' schedule'), @tight_tol)
    assert_in_epsilon(8760, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMechanicalVentilationHouseFan + ' schedule'), @tight_tol)
  end

  def test_simple_vacancy_year_round_schedules
    args_hash = {}
    hpxml_path = File.absolute_path(File.join(sample_files_dir, 'base-schedules-simple-vacancy.xml'))
    hpxml = HPXML.new(hpxml_path: hpxml_path)
    hpxml.header.unavailable_periods[0].begin_month = 1
    hpxml.header.unavailable_periods[0].begin_day = 1
    hpxml.header.unavailable_periods[0].end_month = 12
    hpxml.header.unavailable_periods[0].end_day = 31
    XMLHelper.write_file(hpxml.to_doc(), @tmp_hpxml_path)
    args_hash['hpxml_path'] = @tmp_hpxml_path
    model, _hpxml, _hpxml_bldg = _test_measure(args_hash)

    assert_equal(0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameOccupants + ' schedule'))
    assert_equal(0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingInterior + ' schedule'))
    assert_equal(0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingExterior + ' schedule'))
    assert_in_epsilon(6673, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameRefrigerator + ' schedule'), @tight_tol)
    assert_equal(0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameCookingRange + ' schedule'))
    assert_equal(0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameDishwasher + ' schedule'))
    assert_equal(0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameClothesWasher + ' schedule'))
    assert_equal(0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameClothesDryer + ' schedule'))
    assert_equal(0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMiscPlugLoads + ' schedule'))
    assert_equal(0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMiscTelevision + ' schedule'))
    assert_equal(0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameFixtures + ' schedule'))
    assert_in_epsilon(8760, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMechanicalVentilationHouseFan + ' schedule'), @tight_tol)
  end

  def test_simple_power_outage_schedules
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-schedules-simple-power-outage.xml'))
    model, _hpxml, _hpxml_bldg = _test_measure(args_hash)

    unavailable_month_hrs = { 6 => 31.0 * 24.0 - 15.0 }

    assert_in_epsilon(6020, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameOccupants + ' schedule'), @tight_tol)
    assert_in_epsilon(3405 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.LightingInteriorMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingInterior + ' schedule'), @tight_tol)
    assert_in_epsilon(2763 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.LightingExteriorMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingExterior + ' schedule'), @tight_tol)
    assert_in_epsilon(6673 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.RefrigeratorMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameRefrigerator + ' schedule'), @tight_tol)
    assert_in_epsilon(2224 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.CookingRangeMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameCookingRange + ' schedule'), @tight_tol)
    assert_in_epsilon(2994 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.DishwasherMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameDishwasher + ' schedule'), @tight_tol)
    assert_in_epsilon(4158 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.ClothesWasherMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameClothesWasher + ' schedule'), @tight_tol)
    assert_in_epsilon(4502 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.ClothesDryerMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameClothesDryer + ' schedule'), @tight_tol)
    assert_in_epsilon(5468 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.PlugLoadsOtherMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMiscPlugLoads + ' schedule'), @tight_tol)
    assert_in_epsilon(2956 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.PlugLoadsTVMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMiscTelevision + ' schedule'), @tight_tol)
    assert_in_epsilon(4204 * get_available_hrs_ratio(unavailable_month_hrs, Schedule.FixturesMonthlyMultipliers), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameFixtures + ' schedule'), @tight_tol)
    assert_in_epsilon(8760 * get_available_hrs_ratio(unavailable_month_hrs), get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMechanicalVentilationHouseFan + ' schedule'), @tight_tol)
  end

  def test_stochastic_schedules
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-schedules-detailed-occupancy-stochastic.xml'))
    model, hpxml, hpxml_bldg = _test_measure(args_hash)

    schedule_file_names = []
    model.getScheduleFiles.each do |schedule_file|
      schedule_file_names << "#{schedule_file.name}"
    end
    assert_equal(11, schedule_file_names.size)

    schedules_paths = hpxml_bldg.header.schedules_filepaths.collect { |sfp|
      FilePath.check_path(sfp,
                          File.dirname(args_hash['hpxml_path']),
                          'Schedules')
    }

    sf = SchedulesFile.new(schedules_paths: schedules_paths,
                           year: @year,
                           unavailable_periods: hpxml.header.unavailable_periods,
                           output_path: @tmp_schedule_file_path)

    assert(schedule_file_names.include?(SchedulesFile::ColumnOccupants))
    assert_in_epsilon(6689, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnOccupants, schedules: sf.tmp_schedules), @tight_tol)
    assert(schedule_file_names.include?(SchedulesFile::ColumnLightingInterior))
    assert_in_epsilon(2086, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingInterior, schedules: sf.tmp_schedules), @tight_tol)
    assert(!schedule_file_names.include?(SchedulesFile::ColumnLightingGarage))
    assert_in_epsilon(2086, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingGarage, schedules: sf.tmp_schedules), @tight_tol)
    assert(!schedule_file_names.include?(SchedulesFile::ColumnLightingExterior))
    assert_in_epsilon(2763, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingExterior + ' schedule'), @tight_tol)
    assert(!schedule_file_names.include?(SchedulesFile::ColumnLightingExteriorHoliday))
    assert(!schedule_file_names.include?(SchedulesFile::ColumnRefrigerator))
    assert_in_epsilon(6673, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameRefrigerator + ' schedule'), @tight_tol)
    assert(schedule_file_names.include?(SchedulesFile::ColumnCookingRange))
    assert_in_epsilon(534, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCookingRange, schedules: sf.tmp_schedules), @tight_tol)
    assert(schedule_file_names.include?(SchedulesFile::ColumnDishwasher))
    assert_in_epsilon(213, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnDishwasher, schedules: sf.tmp_schedules), @tight_tol)
    assert(schedule_file_names.include?(SchedulesFile::ColumnClothesWasher))
    assert_in_epsilon(134, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesWasher, schedules: sf.tmp_schedules), @tight_tol)
    assert(schedule_file_names.include?(SchedulesFile::ColumnClothesDryer))
    assert_in_epsilon(151, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesDryer, schedules: sf.tmp_schedules), @tight_tol)
    assert(!schedule_file_names.include?(SchedulesFile::ColumnCeilingFan))
    assert_in_epsilon(3250, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCeilingFan, schedules: sf.tmp_schedules), @tight_tol)
    assert(schedule_file_names.include?(SchedulesFile::ColumnPlugLoadsOther))
    assert_in_epsilon(4840, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsOther, schedules: sf.tmp_schedules), @tight_tol)
    assert(schedule_file_names.include?(SchedulesFile::ColumnPlugLoadsTV))
    assert_in_epsilon(4840, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsTV, schedules: sf.tmp_schedules), @tight_tol)
    assert(schedule_file_names.include?(SchedulesFile::ColumnHotWaterDishwasher))
    assert_in_epsilon(273, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterDishwasher, schedules: sf.tmp_schedules), @tight_tol)
    assert(schedule_file_names.include?(SchedulesFile::ColumnHotWaterClothesWasher))
    assert_in_epsilon(346, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterClothesWasher, schedules: sf.tmp_schedules), @tight_tol)
    assert(schedule_file_names.include?(SchedulesFile::ColumnHotWaterFixtures))
    assert_in_epsilon(887, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterFixtures, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(8760, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMechanicalVentilationHouseFan + ' schedule'), @tight_tol)
    assert(!schedule_file_names.include?(SchedulesFile::ColumnSleeping))
    assert(!schedule_file_names.include?('Vacancy'))
    assert(!schedule_file_names.include?('Power Outage'))
  end

  def test_stochastic_vacancy_schedules
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-schedules-detailed-occupancy-stochastic-vacancy.xml'))
    model, hpxml, hpxml_bldg = _test_measure(args_hash)

    schedules_paths = hpxml_bldg.header.schedules_filepaths.collect { |sfp|
      FilePath.check_path(sfp,
                          File.dirname(args_hash['hpxml_path']),
                          'Schedules')
    }

    column_name = hpxml.header.unavailable_periods[0].column_name

    sf = SchedulesFile.new(schedules_paths: schedules_paths,
                           year: @year,
                           unavailable_periods: hpxml.header.unavailable_periods,
                           output_path: @tmp_schedule_file_path)

    unavailable_month_hrs = { 0 => 31.0 * 24.0, 11 => 31.0 * 24.0 }

    assert_in_epsilon(6689 - 1141, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnOccupants, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(2086 - 411, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingInterior, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(2086 - 411, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingGarage, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(2763 - 587, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingExterior + ' schedule'), @tight_tol)
    assert_in_epsilon(6673 - 0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameRefrigerator + ' schedule'), @tight_tol)
    assert_in_epsilon(534 - 95, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCookingRange, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(213 - 34, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnDishwasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(134 - 23, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesWasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(151 - 25, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesDryer, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(3250 - 630, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCeilingFan, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(4840 - 928, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsOther, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(4840 - 928, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsTV, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(273 - 31, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterDishwasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(346 - 55, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterClothesWasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(887 - 156, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterFixtures, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(8760 - 0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMechanicalVentilationHouseFan + ' schedule'), @tight_tol)
    assert(!sf.schedules.keys.include?(SchedulesFile::ColumnSleeping))
    assert_in_epsilon(unavailable_month_hrs.values.sum, sf.annual_equivalent_full_load_hrs(col_name: column_name, schedules: sf.tmp_schedules), 0.001)
  end

  def test_stochastic_vacancy_schedules2
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-schedules-detailed-occupancy-stochastic-vacancy.xml'))
    _model, hpxml, _hpxml_bldg = _test_measure(args_hash)

    column_name = hpxml.header.unavailable_periods[0].column_name

    # intentionally overlaps the first vacancy period
    hpxml.header.unavailable_periods.add(column_name: column_name,
                                         begin_month: 1,
                                         begin_day: 25,
                                         end_month: 2,
                                         end_day: 28,
                                         natvent_availability: HPXML::ScheduleUnavailable)

    XMLHelper.write_file(hpxml.to_doc(), @tmp_hpxml_path)
    args_hash['hpxml_path'] = @tmp_hpxml_path
    model, hpxml, hpxml_bldg = _test_measure(args_hash)

    schedules_paths = hpxml_bldg.header.schedules_filepaths.collect { |sfp|
      FilePath.check_path(sfp,
                          File.dirname(args_hash['hpxml_path']),
                          'Schedules')
    }

    sf = SchedulesFile.new(schedules_paths: schedules_paths,
                           year: @year,
                           unavailable_periods: hpxml.header.unavailable_periods,
                           output_path: @tmp_schedule_file_path)

    unavailable_month_hrs = { 0 => 31.0 * 24.0, 1 => 28.0 * 24.0, 11 => 31.0 * 24.0 }

    assert_in_epsilon(6689 - 1656, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnOccupants, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(2086 - 595, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingInterior, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(2086 - 595, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingGarage, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(2763 - 853, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingExterior + ' schedule'), @tight_tol)
    assert_in_epsilon(6673 - 0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameRefrigerator + ' schedule'), @tight_tol)
    assert_in_epsilon(534 - 137, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCookingRange, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(213 - 46, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnDishwasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(134 - 36, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesWasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(151 - 42, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesDryer, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(3250 - 919, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCeilingFan, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(4840 - 1348, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsOther, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(4840 - 1348, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsTV, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(273 - 47, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterDishwasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(346 - 100, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterClothesWasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(887 - 224, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterFixtures, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(8760 - 0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMechanicalVentilationHouseFan + ' schedule'), @tight_tol)
    assert(!sf.schedules.keys.include?(SchedulesFile::ColumnSleeping))
    assert_in_epsilon(unavailable_month_hrs.values.sum, sf.annual_equivalent_full_load_hrs(col_name: column_name, schedules: sf.tmp_schedules), 0.001)
  end

  def test_stochastic_vacancy_year_round_schedules
    args_hash = {}
    hpxml_path = File.absolute_path(File.join(sample_files_dir, 'base-schedules-detailed-occupancy-stochastic-vacancy.xml'))
    hpxml = HPXML.new(hpxml_path: hpxml_path)
    hpxml.header.unavailable_periods[0].begin_month = 1
    hpxml.header.unavailable_periods[0].begin_day = 1
    hpxml.header.unavailable_periods[0].end_month = 12
    hpxml.header.unavailable_periods[0].end_day = 31
    XMLHelper.write_file(hpxml.to_doc(), @tmp_hpxml_path)
    args_hash['hpxml_path'] = @tmp_hpxml_path
    model, hpxml, hpxml_bldg = _test_measure(args_hash)

    schedules_paths = hpxml_bldg.header.schedules_filepaths.collect { |sfp|
      FilePath.check_path(sfp,
                          File.dirname(args_hash['hpxml_path']),
                          'Schedules')
    }

    column_name = hpxml.header.unavailable_periods[0].column_name

    sf = SchedulesFile.new(schedules_paths: schedules_paths,
                           year: @year,
                           unavailable_periods: hpxml.header.unavailable_periods,
                           output_path: @tmp_schedule_file_path)

    assert_equal(0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnOccupants, schedules: sf.tmp_schedules))
    assert_equal(0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingInterior, schedules: sf.tmp_schedules))
    assert_equal(0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingGarage, schedules: sf.tmp_schedules))
    assert_equal(0, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingExterior + ' schedule'))
    assert_in_epsilon(6673, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameRefrigerator + ' schedule'), @tight_tol)
    assert_equal(0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCookingRange, schedules: sf.tmp_schedules))
    assert_equal(0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnDishwasher, schedules: sf.tmp_schedules))
    assert_equal(0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesWasher, schedules: sf.tmp_schedules))
    assert_equal(0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesDryer, schedules: sf.tmp_schedules))
    assert_equal(0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCeilingFan, schedules: sf.tmp_schedules))
    assert_equal(0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsOther, schedules: sf.tmp_schedules))
    assert_equal(0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsTV, schedules: sf.tmp_schedules))
    assert_equal(0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterDishwasher, schedules: sf.tmp_schedules))
    assert_equal(0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterClothesWasher, schedules: sf.tmp_schedules))
    assert_equal(0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterFixtures, schedules: sf.tmp_schedules))
    assert_in_epsilon(8760, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMechanicalVentilationHouseFan + ' schedule'), @tight_tol)
    assert(!sf.schedules.keys.include?(SchedulesFile::ColumnSleeping))
    assert_in_epsilon(Constants.NumHoursInYear(@year), sf.annual_equivalent_full_load_hrs(col_name: column_name, schedules: sf.tmp_schedules), @tight_tol)
  end

  def test_stochastic_power_outage_schedules
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-schedules-detailed-occupancy-stochastic-power-outage.xml'))
    model, hpxml, hpxml_bldg = _test_measure(args_hash)

    schedules_paths = hpxml_bldg.header.schedules_filepaths.collect { |sfp|
      FilePath.check_path(sfp,
                          File.dirname(args_hash['hpxml_path']),
                          'Schedules')
    }

    column_name = hpxml.header.unavailable_periods[0].column_name

    sf = SchedulesFile.new(schedules_paths: schedules_paths,
                           year: @year,
                           unavailable_periods: hpxml.header.unavailable_periods,
                           output_path: @tmp_schedule_file_path)

    unavailable_month_hrs = { 0 => 31.0 * 24.0 - 10.0, 11 => 31.0 * 24.0 - 5.0 }

    assert_in_epsilon(6689 - 0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnOccupants, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(2086 - 408, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingInterior, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(2086 - 408, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingGarage, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(2763 - 579, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingExterior + ' schedule'), @tight_tol)
    assert_in_epsilon(6673 - 938, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameRefrigerator + ' schedule'), @tight_tol)
    assert_in_epsilon(534 - 94, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCookingRange, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(213 - 34, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnDishwasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(134 - 23, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesWasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(151 - 25, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesDryer, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(3250 - 625, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCeilingFan, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(4840 - 920, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsOther, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(4840 - 920, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsTV, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(273 - 31, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterDishwasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(346 - 55, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterClothesWasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(887 - 155, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterFixtures, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(8760 - 1473, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMechanicalVentilationHouseFan + ' schedule'), @tight_tol)
    assert(!sf.schedules.keys.include?(SchedulesFile::ColumnSleeping))
    assert_in_epsilon(unavailable_month_hrs.values.sum, sf.annual_equivalent_full_load_hrs(col_name: column_name, schedules: sf.tmp_schedules), 0.001)
  end

  def test_stochastic_power_outage_schedules2
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-schedules-detailed-occupancy-stochastic-power-outage.xml'))
    _model, hpxml, _hpxml_bldg = _test_measure(args_hash)

    column_name = hpxml.header.unavailable_periods[0].column_name

    # intentionally overlaps the first power outage period
    hpxml.header.unavailable_periods.add(column_name: column_name,
                                         begin_month: 1,
                                         begin_day: 25,
                                         begin_hour: 0,
                                         end_month: 2,
                                         end_day: 27,
                                         end_hour: 24)

    XMLHelper.write_file(hpxml.to_doc(), @tmp_hpxml_path)
    args_hash['hpxml_path'] = @tmp_hpxml_path
    model, hpxml, hpxml_bldg = _test_measure(args_hash)

    schedules_paths = hpxml_bldg.header.schedules_filepaths.collect { |sfp|
      FilePath.check_path(sfp,
                          File.dirname(args_hash['hpxml_path']),
                          'Schedules')
    }

    sf = SchedulesFile.new(schedules_paths: schedules_paths,
                           year: @year,
                           unavailable_periods: hpxml.header.unavailable_periods,
                           output_path: @tmp_schedule_file_path)

    unavailable_month_hrs = { 0 => 31.0 * 24.0, 1 => 28.0 * 24.0 - 24.0, 11 => 31.0 * 24.0 - 5.0 }

    assert_in_epsilon(6689 - 0, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnOccupants, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(2086 - 588, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingInterior, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(2086 - 588, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnLightingGarage, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(2763 - 842, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameLightingExterior + ' schedule'), @tight_tol)
    assert_in_epsilon(6673 - 1357, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameRefrigerator + ' schedule'), @tight_tol)
    assert_in_epsilon(534 - 135, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCookingRange, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(213 - 45, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnDishwasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(134 - 36, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesWasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(151 - 42, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnClothesDryer, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(3250 - 907, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnCeilingFan, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(4840 - 1330, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsOther, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(4840 - 1330, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnPlugLoadsTV, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(273 - 46, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterDishwasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(346 - 100, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterClothesWasher, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(887 - 222, sf.annual_equivalent_full_load_hrs(col_name: SchedulesFile::ColumnHotWaterFixtures, schedules: sf.tmp_schedules), @tight_tol)
    assert_in_epsilon(8760 - 2131, get_annual_equivalent_full_load_hrs(model, Constants.ObjectNameMechanicalVentilationHouseFan + ' schedule'), @tight_tol)
    assert(!sf.schedules.keys.include?(SchedulesFile::ColumnSleeping))
    assert_in_epsilon(unavailable_month_hrs.values.sum, sf.annual_equivalent_full_load_hrs(col_name: column_name, schedules: sf.tmp_schedules), 0.001)
  end

  def test_set_unavailable_periods_refrigerator
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))

    begin_month = 1
    begin_day = 1
    begin_hour = 0
    end_month = 12
    end_day = 31
    end_hour = 24

    sch_name = Constants.ObjectNameRefrigerator + ' schedule'

    # hours not specified
    model, hpxml, _hpxml_bldg = _test_measure(args_hash)
    year = model.getYearDescription.assumedYear

    schedule = model.getScheduleRulesets.find { |schedule| schedule.name.to_s == sch_name }
    unavailable_periods = _add_unavailable_period(hpxml, 'Power Outage', begin_month, begin_day, begin_hour, end_month, end_day, end_hour)

    schedule_rules = schedule.scheduleRules
    Schedule.set_unavailable_periods(schedule, sch_name, unavailable_periods, year)
    unavailable_schedule_rules = schedule.scheduleRules - schedule_rules

    assert_equal(1, unavailable_schedule_rules.size)

    _test_day_schedule(schedule, begin_month, begin_day, year, 0, 24)
    _test_day_schedule(schedule, begin_month + 5, begin_day + 10, year, 0, 24)
    _test_day_schedule(schedule, end_month, end_day, year, 0, 24)

    # 1 calendar day
    end_month = 1
    end_day = 1
    end_hour = 5

    model, hpxml, _hpxml_bldg = _test_measure(args_hash)
    year = model.getYearDescription.assumedYear

    schedule = model.getScheduleRulesets.find { |schedule| schedule.name.to_s == sch_name }
    unavailable_periods = _add_unavailable_period(hpxml, 'Power Outage', begin_month, begin_day, begin_hour, end_month, end_day, end_hour) # note the change of end month/day

    schedule_rules = schedule.scheduleRules
    Schedule.set_unavailable_periods(schedule, sch_name, unavailable_periods, year)
    unavailable_schedule_rules = schedule.scheduleRules - schedule_rules

    assert_equal(1, unavailable_schedule_rules.size)

    _test_day_schedule(schedule, begin_month, begin_day, year, 0, end_hour)
    _test_day_schedule(schedule, end_month, begin_day + 1, year, nil, nil)

    # 2 calendar days, partial first day
    begin_hour = 5
    end_day = 2
    end_hour = 24

    model, hpxml, _hpxml_bldg = _test_measure(args_hash)
    year = model.getYearDescription.assumedYear

    schedule = model.getScheduleRulesets.find { |schedule| schedule.name.to_s == sch_name }
    unavailable_periods = _add_unavailable_period(hpxml, 'Power Outage', begin_month, begin_day, begin_hour, end_month, end_day, end_hour) # note the change of end month/day

    schedule_rules = schedule.scheduleRules
    Schedule.set_unavailable_periods(schedule, sch_name, unavailable_periods, year)
    unavailable_schedule_rules = schedule.scheduleRules - schedule_rules

    assert_equal(2, unavailable_schedule_rules.size)

    _test_day_schedule(schedule, begin_month, begin_day, year, begin_hour, 24)
    _test_day_schedule(schedule, end_month, begin_day + 1, year, 0, 24)
    _test_day_schedule(schedule, end_month, begin_day + 2, year, nil, nil)

    # 2 calendar days, partial last day
    begin_hour = 0
    end_day = 2
    end_hour = 11

    model, hpxml, _hpxml_bldg = _test_measure(args_hash)
    year = model.getYearDescription.assumedYear

    schedule = model.getScheduleRulesets.find { |schedule| schedule.name.to_s == sch_name }
    unavailable_periods = _add_unavailable_period(hpxml, 'Power Outage', begin_month, begin_day, begin_hour, end_month, end_day, end_hour) # note the change of end month/day

    schedule_rules = schedule.scheduleRules
    Schedule.set_unavailable_periods(schedule, sch_name, unavailable_periods, year)
    unavailable_schedule_rules = schedule.scheduleRules - schedule_rules

    assert_equal(2, unavailable_schedule_rules.size)

    _test_day_schedule(schedule, begin_month, begin_day, year, 0, 24)
    _test_day_schedule(schedule, end_month, end_day, year, 0, end_hour)
    _test_day_schedule(schedule, end_month, end_day + 1, year, nil, nil)

    # wrap around
    begin_month = 12
    begin_day = 1
    begin_hour = 5
    end_month = 1
    end_day = 31
    end_hour = 12

    model, hpxml, _hpxml_bldg = _test_measure(args_hash)
    year = model.getYearDescription.assumedYear

    schedule = model.getScheduleRulesets.find { |schedule| schedule.name.to_s == sch_name }
    unavailable_periods = _add_unavailable_period(hpxml, 'Power Outage', begin_month, begin_day, begin_hour, end_month, end_day, end_hour) # note the change of end month/day

    schedule_rules = schedule.scheduleRules
    Schedule.set_unavailable_periods(schedule, sch_name, unavailable_periods, year)
    unavailable_schedule_rules = schedule.scheduleRules - schedule_rules

    assert_equal(3, unavailable_schedule_rules.size)

    _test_day_schedule(schedule, begin_month, begin_day, year, begin_hour, 24)
    _test_day_schedule(schedule, end_month + 5, begin_day + 10, year, nil, nil)
    _test_day_schedule(schedule, end_month, end_day, year, 0, end_hour)
  end

  def test_set_unavailable_periods_natvent
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base.xml'))

    # normal availability
    begin_month = 1
    begin_day = 1
    begin_hour = 0
    end_month = 6
    end_day = 30
    end_hour = 24
    natvent_availability = HPXML::ScheduleRegular

    sch_name = "#{Constants.ObjectNameNaturalVentilation} schedule"

    model, hpxml, _hpxml_bldg = _test_measure(args_hash)
    year = model.getYearDescription.assumedYear

    schedule = model.getScheduleRulesets.find { |schedule| schedule.name.to_s == sch_name }
    unavailable_periods = _add_unavailable_period(hpxml, 'Power Outage', begin_month, begin_day, begin_hour, end_month, end_day, end_hour, natvent_availability)

    schedule_rules = schedule.scheduleRules
    Schedule.set_unavailable_periods(schedule, sch_name, unavailable_periods, year)
    unavailable_schedule_rules = schedule.scheduleRules - schedule_rules

    assert_equal(0, unavailable_schedule_rules.size)

    _test_day_schedule(schedule, begin_month, begin_day, year, 0, 24, 1)
    _test_day_schedule(schedule, begin_month, begin_day + 1, year, 0, 24, 0)

    # not available
    natvent_availability = HPXML::ScheduleUnavailable

    model, hpxml, _hpxml_bldg = _test_measure(args_hash)
    year = model.getYearDescription.assumedYear

    schedule = model.getScheduleRulesets.find { |schedule| schedule.name.to_s == sch_name }
    unavailable_periods = _add_unavailable_period(hpxml, 'Power Outage', begin_month, begin_day, begin_hour, end_month, end_day, end_hour, natvent_availability)

    schedule_rules = schedule.scheduleRules
    Schedule.set_unavailable_periods(schedule, sch_name, unavailable_periods, year)
    unavailable_schedule_rules = schedule.scheduleRules - schedule_rules

    assert_equal(1, unavailable_schedule_rules.size)

    _test_day_schedule(schedule, begin_month, begin_day, year, 0, 24, 0)
    _test_day_schedule(schedule, begin_month, begin_day + 1, year, 0, 24, 0)

    # available
    natvent_availability = HPXML::ScheduleAvailable

    model, hpxml, _hpxml_bldg = _test_measure(args_hash)
    year = model.getYearDescription.assumedYear

    schedule = model.getScheduleRulesets.find { |schedule| schedule.name.to_s == sch_name }
    unavailable_periods = _add_unavailable_period(hpxml, 'Power Outage', begin_month, begin_day, begin_hour, end_month, end_day, end_hour, natvent_availability)

    schedule_rules = schedule.scheduleRules
    Schedule.set_unavailable_periods(schedule, sch_name, unavailable_periods, year)
    unavailable_schedule_rules = schedule.scheduleRules - schedule_rules

    assert_equal(1, unavailable_schedule_rules.size)

    _test_day_schedule(schedule, begin_month, begin_day, year, 0, 24, 1)
    _test_day_schedule(schedule, begin_month, begin_day + 1, year, 0, 24, 1)
  end

  def test_set_unavailable_periods_leap_year
    args_hash = {}
    args_hash['hpxml_path'] = File.absolute_path(File.join(sample_files_dir, 'base-location-AMY-2012.xml'))

    begin_month = 1
    begin_day = 1
    begin_hour = 0
    end_month = 3
    end_day = 30
    end_hour = 24

    sch_name = Constants.ObjectNameRefrigerator + ' schedule'

    model, hpxml, _hpxml_bldg = _test_measure(args_hash)
    year = model.getYearDescription.assumedYear
    assert_equal(2012, year)

    schedule = model.getScheduleRulesets.find { |schedule| schedule.name.to_s == sch_name }
    unavailable_periods = _add_unavailable_period(hpxml, 'Power Outage', begin_month, begin_day, begin_hour, end_month, end_day, end_hour)

    schedule_rules = schedule.scheduleRules
    Schedule.set_unavailable_periods(schedule, sch_name, unavailable_periods, year)
    unavailable_schedule_rules = schedule.scheduleRules - schedule_rules

    assert_equal(1, unavailable_schedule_rules.size)

    _test_day_schedule(schedule, 2, 28, year, 0, 24)
    _test_day_schedule(schedule, 2, 29, year, 0, 24)
    _test_day_schedule(schedule, 3, 1, year, 0, 24)
  end

  def _add_unavailable_period(hpxml, column_name, begin_month, begin_day, begin_hour, end_month, end_day, end_hour, natvent_availability = nil)
    hpxml.header.unavailable_periods.add(column_name: column_name,
                                         begin_month: begin_month,
                                         begin_day: begin_day,
                                         begin_hour: begin_hour,
                                         end_month: end_month,
                                         end_day: end_day,
                                         end_hour: end_hour,
                                         natvent_availability: natvent_availability)
    return hpxml.header.unavailable_periods
  end

  def _test_day_schedule(schedule, month, day, year, begin_hour, end_hour, expected_value = 0)
    month_of_year = OpenStudio::MonthOfYear.new(month)
    date = OpenStudio::Date.new(month_of_year, day, year)
    day_schedule = schedule.getDaySchedules(date, date)[0]

    (0..23).each do |h|
      time = OpenStudio::Time.new(0, h + 1, 0, 0)
      actual_value = day_schedule.getValue(time)
      if (begin_hour.nil? && end_hour.nil?) || (h < begin_hour) || (h >= end_hour)
        assert_operator(actual_value, :>, expected_value)
      else
        assert_equal(expected_value, actual_value)
      end
    end
  end

  def _test_measure(args_hash)
    # create an instance of the measure
    measure = HPXMLtoOpenStudio.new

    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    model = OpenStudio::Model::Model.new

    # get arguments
    args_hash['output_dir'] = File.dirname(__FILE__)
    arguments = measure.arguments(model)
    argument_map = OpenStudio::Measure.convertOSArgumentVectorToMap(arguments)

    # populate argument with specified hash value if specified
    arguments.each do |arg|
      temp_arg_var = arg.clone
      if args_hash.has_key?(arg.name)
        assert(temp_arg_var.setValue(args_hash[arg.name]))
      end
      argument_map[arg.name] = temp_arg_var
    end

    # run the measure
    measure.run(model, runner, argument_map)
    result = runner.result

    # show the output
    show_output(result) unless result.value.valueName == 'Success'

    # assert that it ran correctly
    assert_equal('Success', result.value.valueName)

    hpxml = HPXML.new(hpxml_path: args_hash['hpxml_path'])

    File.delete(File.join(File.dirname(__FILE__), 'in.xml'))

    return model, hpxml, hpxml.buildings[0]
  end
end
