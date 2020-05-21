# frozen_string_literal: true

require_relative '../resources/minitest_helper'
require 'openstudio'
require 'openstudio/ruleset/ShowRunnerOutput'
require 'minitest/autorun'
require 'fileutils'
require_relative '../measure.rb'
require_relative '../resources/util.rb'

class HPXMLtoOpenStudioDuctsTest < MiniTest::Test
  def before_setup
    @root_path = File.absolute_path(File.join(File.dirname(__FILE__), '..', '..'))
    @tmp_hpxml_path = File.join(@root_path, 'workflow', 'sample_files', 'tmp.xml')
    @tmp_output_path = File.join(@root_path, 'workflow', 'sample_files', 'tmp_output')
    @tmp_output_hpxml_path = File.join(@tmp_output_path, 'in.xml')
    FileUtils.mkdir_p(@tmp_output_path)

    @args_hash = {}
    @args_hash['hpxml_path'] = File.absolute_path(@tmp_hpxml_path)
    @args_hash['debug'] = true
    @args_hash['output_dir'] = File.absolute_path(@tmp_output_path)
  end

  def after_teardown
    File.delete(@tmp_hpxml_path) if File.exist? @tmp_hpxml_path
    FileUtils.rm_rf(@tmp_output_path)
  end

  def test_ducts
    hpxml_name = 'base.xml'
    hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_supply_locations = ['attic - unvented']
    expected_return_locations = ['attic - unvented']
    expected_supply_areas = [150.0]
    expected_return_areas = [50.0]
    expected_n_return_registers = hpxml.building_construction.number_of_conditioned_floors
    _test_default_duct_values(hpxml, expected_supply_locations, expected_return_locations, expected_supply_areas, expected_return_areas, expected_n_return_registers)

    default_hpxml('base.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_supply_locations = ['basement - conditioned']
    expected_return_locations = ['basement - conditioned']
    expected_supply_areas = [729.0]
    expected_return_areas = [270.0]
    expected_n_return_registers = hpxml.building_construction.number_of_conditioned_floors
    _test_default_duct_values(hpxml, expected_supply_locations, expected_return_locations, expected_supply_areas, expected_return_areas, expected_n_return_registers)

    default_hpxml('base-foundation-multiple.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_supply_locations = ['basement - unconditioned']
    expected_return_locations = ['basement - unconditioned']
    expected_supply_areas = [364.5]
    expected_return_areas = [67.5]
    expected_n_return_registers = hpxml.building_construction.number_of_conditioned_floors
    _test_default_duct_values(hpxml, expected_supply_locations, expected_return_locations, expected_supply_areas, expected_return_areas, expected_n_return_registers)

    default_hpxml('base-foundation-ambient.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_supply_locations = ['attic - unvented']
    expected_return_locations = ['attic - unvented']
    expected_supply_areas = [364.5]
    expected_return_areas = [67.5]
    expected_n_return_registers = hpxml.building_construction.number_of_conditioned_floors
    _test_default_duct_values(hpxml, expected_supply_locations, expected_return_locations, expected_supply_areas, expected_return_areas, expected_n_return_registers)

    default_hpxml('base-enclosure-other-housing-unit.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_supply_locations = ['living space']
    expected_return_locations = ['living space']
    expected_supply_areas = [364.5]
    expected_return_areas = [67.5]
    expected_n_return_registers = hpxml.building_construction.number_of_conditioned_floors
    _test_default_duct_values(hpxml, expected_supply_locations, expected_return_locations, expected_supply_areas, expected_return_areas, expected_n_return_registers)

    default_hpxml('base-enclosure-2stories.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_supply_locations = ['basement - conditioned', 'living space']
    expected_return_locations = ['basement - conditioned', 'living space']
    expected_supply_areas = [820.125, 273.375]
    expected_return_areas = [455.625, 151.875]
    expected_n_return_registers = hpxml.building_construction.number_of_conditioned_floors
    _test_default_duct_values(hpxml, expected_supply_locations, expected_return_locations, expected_supply_areas, expected_return_areas, expected_n_return_registers)

    hpxml_files = ['base-hvac-multiple.xml',
                   'base-hvac-multiple2.xml']
    hpxml_files.each do |hpxml_file|
      default_hpxml(hpxml_file)
      model, hpxml = _test_measure(@args_hash)
      expected_supply_locations = ['basement - conditioned', 'basement - conditioned'] * hpxml.hvac_distributions.size
      expected_return_locations = ['basement - conditioned', 'basement - conditioned'] * hpxml.hvac_distributions.size
      expected_supply_areas = [91.125, 91.125] * hpxml.hvac_distributions.size
      expected_return_areas = [33.75, 33.75] * hpxml.hvac_distributions.size
      expected_n_return_registers = hpxml.building_construction.number_of_conditioned_floors
      _test_default_duct_values(hpxml, expected_supply_locations, expected_return_locations, expected_supply_areas, expected_return_areas, expected_n_return_registers)
    end

    hpxml = default_hpxml('base-hvac-multiple.xml')
    hpxml.building_construction.number_of_conditioned_floors_above_grade = 2
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_supply_locations = ['basement - conditioned', 'basement - conditioned', 'living space', 'living space'] * hpxml.hvac_distributions.size
    expected_return_locations = ['basement - conditioned', 'basement - conditioned', 'living space', 'living space'] * hpxml.hvac_distributions.size
    expected_supply_areas = [68.34375, 68.34375, 22.78125, 22.78125] * hpxml.hvac_distributions.size
    expected_return_areas = [25.3125, 25.3125, 8.4375, 8.4375] * hpxml.hvac_distributions.size
    expected_n_return_registers = hpxml.building_construction.number_of_conditioned_floors
    _test_default_duct_values(hpxml, expected_supply_locations, expected_return_locations, expected_supply_areas, expected_return_areas, expected_n_return_registers)
  end

  def test_pv
    hpxml_name = 'base-pv.xml'
    hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_interver_efficiency = [0.96, 0.96]
    expected_system_loss_frac = [0.14, 0.14]
    _test_default_pv(hpxml, expected_interver_efficiency, expected_system_loss_frac)

    default_hpxml('base-pv.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_interver_efficiency = [0.96, 0.96]
    expected_system_loss_frac = [0.14, 0.14]
    _test_default_pv(hpxml, expected_interver_efficiency, expected_system_loss_frac)

    hpxml = default_hpxml('base-pv.xml')
    hpxml.pv_systems.each do |pv|
      pv.year_modules_manufactured = 2010
    end
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_interver_efficiency = [0.96, 0.96]
    expected_system_loss_frac = [0.182, 0.182]
    _test_default_pv(hpxml, expected_interver_efficiency, expected_system_loss_frac)
  end

  def test_conditioned_building_volume
    hpxml_name = 'base.xml'
    hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_building_volume = 21600
    _test_default_conditioned_building_volume(hpxml, expected_building_volume)

    default_hpxml('base.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_building_volume = 27000
    _test_default_conditioned_building_volume(hpxml, expected_building_volume)
  end

  def test_appliances
    hpxml_name = 'base.xml'
    hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_cw_values = [HPXML::LocationLivingSpace, 1.21, 380.0, 0.12, 1.09, 27.0, 3.2, 6.0, 1.0]
    expected_cd_values = [HPXML::LocationLivingSpace, HPXML::ClothesDryerControlTypeTimer, 3.73, 1.0]
    expected_dw_values = [HPXML::LocationLivingSpace, 307.0, 0.12, 1.09, 22.32, 4.0, 12, 1.0]
    expected_refrig_values = [HPXML::LocationLivingSpace, 650.0, 1.0]
    expected_cr_values = [HPXML::LocationLivingSpace, false, 1.0]
    expected_oven_values = false
    _test_default_clothes_washer(hpxml, expected_cw_values)
    _test_default_clothes_dryer(hpxml, expected_cd_values)
    _test_default_dish_washer(hpxml, expected_dw_values)
    _test_default_refrigerator(hpxml, expected_refrig_values)
    _test_default_cooking_range(hpxml, expected_cr_values)
    _test_default_oven(hpxml, expected_oven_values)

    hpxml = default_hpxml('base.xml')
    hpxml.header.eri_calculation_version = '2014ADEGL'
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_cw_values = [HPXML::LocationLivingSpace, 0.331, 704.0, 0.08, 0.58, 23.0, 2.874, 6.0, 1.0]
    expected_cd_values = [HPXML::LocationLivingSpace, HPXML::ClothesDryerControlTypeTimer, 2.62, 1.0]
    expected_dw_values = [HPXML::LocationLivingSpace, 467.0, 0.12, 1.09, 33.12, 4.0, 12, 1.0]
    expected_refrig_values = [HPXML::LocationLivingSpace, 691.0, 1.0]
    expected_cr_values = [HPXML::LocationLivingSpace, false, 1.0]
    expected_oven_values = false
    _test_default_clothes_washer(hpxml, expected_cw_values)
    _test_default_clothes_dryer(hpxml, expected_cd_values)
    _test_default_dish_washer(hpxml, expected_dw_values)
    _test_default_refrigerator(hpxml, expected_refrig_values)
    _test_default_cooking_range(hpxml, expected_cr_values)
    _test_default_oven(hpxml, expected_oven_values)

    hpxml = default_hpxml('base.xml')
    hpxml.header.eri_calculation_version = '2014ADEGL'
    hpxml.clothes_dryers[0].fuel_type = HPXML::FuelTypeNaturalGas
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_cw_values = [HPXML::LocationLivingSpace, 0.331, 704.0, 0.08, 0.58, 23.0, 2.874, 6.0, 1.0]
    expected_cd_values = [HPXML::LocationLivingSpace, HPXML::ClothesDryerControlTypeTimer, 2.32, 1.0]
    expected_dw_values = [HPXML::LocationLivingSpace, 467.0, 0.12, 1.09, 33.12, 4.0, 12, 1.0]
    expected_refrig_values = [HPXML::LocationLivingSpace, 691.0, 1.0]
    expected_cr_values = [HPXML::LocationLivingSpace, false, 1.0]
    expected_oven_values = false
    _test_default_clothes_washer(hpxml, expected_cw_values)
    _test_default_clothes_dryer(hpxml, expected_cd_values)
    _test_default_dish_washer(hpxml, expected_dw_values)
    _test_default_refrigerator(hpxml, expected_refrig_values)
    _test_default_cooking_range(hpxml, expected_cr_values)
    _test_default_oven(hpxml, expected_oven_values)

    default_hpxml('base.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_cw_values = [HPXML::LocationLivingSpace, 1.0, 400.0, 0.12, 1.09, 27.0, 3.0, 6.0, 1.0]
    expected_cd_values = [HPXML::LocationLivingSpace, HPXML::ClothesDryerControlTypeTimer, 3.01, 1.0]
    expected_dw_values = [HPXML::LocationLivingSpace, 467.0, 0.12, 1.09, 33.12, 4.0, 12, 1.0]
    expected_refrig_values = [HPXML::LocationLivingSpace, 691.0, 1.0]
    expected_cr_values = [HPXML::LocationLivingSpace, false, 1.0]
    expected_oven_values = false
    _test_default_clothes_washer(hpxml, expected_cw_values)
    _test_default_clothes_dryer(hpxml, expected_cd_values)
    _test_default_dish_washer(hpxml, expected_dw_values)
    _test_default_refrigerator(hpxml, expected_refrig_values)
    _test_default_cooking_range(hpxml, expected_cr_values)
    _test_default_oven(hpxml, expected_oven_values)

    hpxml = default_hpxml('base.xml')
    hpxml.clothes_dryers[0].fuel_type = HPXML::FuelTypeNaturalGas
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_cw_values = [HPXML::LocationLivingSpace, 1.0, 400.0, 0.12, 1.09, 27.0, 3.0, 6.0, 1.0]
    expected_cd_values = [HPXML::LocationLivingSpace, HPXML::ClothesDryerControlTypeTimer, 3.01, 1.0]
    expected_dw_values = [HPXML::LocationLivingSpace, 467.0, 0.12, 1.09, 33.12, 4.0, 12, 1.0]
    expected_refrig_values = [HPXML::LocationLivingSpace, 691.0, 1.0]
    expected_cr_values = [HPXML::LocationLivingSpace, false, 1.0]
    expected_oven_values = false
    _test_default_clothes_washer(hpxml, expected_cw_values)
    _test_default_clothes_dryer(hpxml, expected_cd_values)
    _test_default_dish_washer(hpxml, expected_dw_values)
    _test_default_refrigerator(hpxml, expected_refrig_values)
    _test_default_cooking_range(hpxml, expected_cr_values)
    _test_default_oven(hpxml, expected_oven_values)

    hpxml = default_hpxml('base-enclosure-beds-5.xml')
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_cw_values = [HPXML::LocationLivingSpace, 1.0, 400.0, 0.12, 1.09, 27.0, 3.0, 6.0, 1.0]
    expected_cd_values = [HPXML::LocationLivingSpace, HPXML::ClothesDryerControlTypeTimer, 3.01, 1.0]
    expected_dw_values = [HPXML::LocationLivingSpace, 467.0, 0.12, 1.09, 33.12, 4.0, 12, 1.0]
    expected_refrig_values = [HPXML::LocationLivingSpace, 727.0, 1.0]
    expected_cr_values = [HPXML::LocationLivingSpace, false, 1.0]
    expected_oven_values = false
    _test_default_clothes_washer(hpxml, expected_cw_values)
    _test_default_clothes_dryer(hpxml, expected_cd_values)
    _test_default_dish_washer(hpxml, expected_dw_values)
    _test_default_refrigerator(hpxml, expected_refrig_values)
    _test_default_cooking_range(hpxml, expected_cr_values)
    _test_default_oven(hpxml, expected_oven_values)
  end

  def test_hot_water_distribution
    hpxml_name = 'base.xml'
    hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_hw_piping_length = 50.0
    _test_default_std_hot_water_distribution(hpxml, expected_hw_piping_length)

    default_hpxml('base.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_hw_piping_length = 93.48
    _test_default_std_hot_water_distribution(hpxml, expected_hw_piping_length)

    default_hpxml('base-foundation-unconditioned-basement.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_hw_piping_length = 88.48
    _test_default_std_hot_water_distribution(hpxml, expected_hw_piping_length)

    default_hpxml('base-enclosure-2stories.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_std_hw_piping_length = 103.48
    _test_default_std_hot_water_distribution(hpxml, expected_std_hw_piping_length)

    hpxml_name = 'base-dhw-recirc-demand.xml'
    hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_recirc_hw_dist_values = [50.0, 50.0, 50.0]
    _test_default_recirc_hot_water_distribution(hpxml, expected_recirc_hw_dist_values)
  
    hpxml = default_hpxml('base-dhw-recirc-demand.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_recirc_hw_dist_values = [166.96, 10.0, 50.0]
    _test_default_recirc_hot_water_distribution(hpxml, expected_recirc_hw_dist_values)
  
    hpxml = default_hpxml('base-enclosure-2stories.xml')
    hpxml.hot_water_distributions.clear
    hpxml.hot_water_distributions.add(id: 'HotWaterDstribution',
                                      system_type: HPXML::DHWDistTypeRecirc,
                                      recirculation_control_type: HPXML::DHWRecirControlTypeSensor,
                                      pipe_r_value: 3.0)
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_recirc_hw_dist_values = [186.96, 10.0, 50.0]
    _test_default_recirc_hot_water_distribution(hpxml, expected_recirc_hw_dist_values)
  end

  def test_solar_thermal_system
    hpxml_name = 'base-dhw-solar-direct-flat-plate.xml'
    hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_storage_volume = 60.0
    _test_default_solar_thermal_system(hpxml, expected_storage_volume)

    hpxml = default_hpxml('base-dhw-solar-direct-flat-plate.xml')
    model, hpxml = _test_measure(@args_hash)
    expected_storage_volume = 60.0
    _test_default_solar_thermal_system(hpxml, expected_storage_volume)

    hpxml = default_hpxml('base-dhw-solar-direct-flat-plate.xml')
    hpxml.solar_thermal_systems[0].collector_area = 100.0
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)
    model, hpxml = _test_measure(@args_hash)
    expected_storage_volume = 150.0
    _test_default_solar_thermal_system(hpxml, expected_storage_volume)
  end

  def _test_measure(args_hash)
    # create an instance of the measure
    measure = HPXMLtoOpenStudio.new

    runner = OpenStudio::Measure::OSRunner.new(OpenStudio::WorkflowJSON.new)
    model = OpenStudio::Model::Model.new

    # get arguments
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

    hpxml = HPXML.new(hpxml_path: @tmp_output_hpxml_path)

    return model, hpxml
  end

  def _test_default_duct_values(hpxml, expected_supply_locations, expected_return_locations, expected_supply_areas, expected_return_areas, expected_n_return_registers)
    supply_duct_idx = 0
    return_duct_idx = 0
    hpxml.hvac_distributions.each do |hvac_distribution|
      assert_equal(hvac_distribution.number_of_return_registers, expected_n_return_registers) if hvac_distribution.distribution_system_type == HPXML::HVACDistributionTypeAir
      hvac_distribution.ducts.each do |duct|
        if duct.duct_type == HPXML::DuctTypeSupply
          assert_equal(duct.duct_location, expected_supply_locations[supply_duct_idx])
          assert_in_epsilon(duct.duct_surface_area, expected_supply_areas[supply_duct_idx], 0.01)
          supply_duct_idx += 1
        elsif duct.duct_type == HPXML::DuctTypeReturn
          assert_equal(duct.duct_location, expected_return_locations[return_duct_idx])
          assert_in_epsilon(duct.duct_surface_area, expected_return_areas[return_duct_idx], 0.01)
          return_duct_idx += 1
        end
      end
    end
  end

  def _test_default_pv(hpxml, expected_interver_efficiency, expected_system_loss_frac)
    hpxml.pv_systems.each_with_index do |pv, idx|
      assert_equal(pv.inverter_efficiency, expected_interver_efficiency[idx])
      assert_in_epsilon(pv.system_losses_fraction, expected_system_loss_frac[idx], 0.01)
    end
  end

  def _test_default_conditioned_building_volume(hpxml, expected_building_volume)
    assert_equal(hpxml.building_construction.conditioned_building_volume, expected_building_volume)
  end

  def _test_default_clothes_washer(hpxml, expected_cw_values)
    cw_location, cw_imef, cw_rated_annual_kwh, cw_label_electric_rate, cw_label_gas_rate, cw_label_annual_gas_cost, cw_capacity, cw_label_usage, cw_usage_multiplier = expected_cw_values
    assert_equal(hpxml.clothes_washers[0].location, cw_location)
    assert_equal(hpxml.clothes_washers[0].integrated_modified_energy_factor, cw_imef)
    assert_equal(hpxml.clothes_washers[0].rated_annual_kwh, cw_rated_annual_kwh)
    assert_equal(hpxml.clothes_washers[0].label_electric_rate, cw_label_electric_rate)
    assert_equal(hpxml.clothes_washers[0].label_gas_rate, cw_label_gas_rate)
    assert_equal(hpxml.clothes_washers[0].label_annual_gas_cost, cw_label_annual_gas_cost)
    assert_equal(hpxml.clothes_washers[0].capacity, cw_capacity)
    assert_equal(hpxml.clothes_washers[0].label_usage, cw_label_usage)
    assert_equal(hpxml.clothes_washers[0].usage_multiplier, cw_usage_multiplier)
  end

  def _test_default_clothes_dryer(hpxml, expected_cd_values)
    cd_location, cd_control_type, cd_cef, cd_usage_multiplier = expected_cd_values
    assert_equal(hpxml.clothes_dryers[0].location, cd_location)
    assert_equal(hpxml.clothes_dryers[0].control_type, cd_control_type)
    assert_equal(hpxml.clothes_dryers[0].combined_energy_factor, cd_cef)
    assert_equal(hpxml.clothes_dryers[0].usage_multiplier, cd_usage_multiplier)
  end

  def _test_default_dish_washer(hpxml, expected_dw_values)
    dw_location, dw_rated_annual_kwh, dw_label_electric_rate, dw_label_gas_rate, dw_label_annual_gas_cost, dw_label_usage, dw_place_setting_capacity, dw_usage_multiplier = expected_dw_values
    assert_equal(hpxml.dishwashers[0].location, dw_location)
    assert_equal(hpxml.dishwashers[0].rated_annual_kwh, dw_rated_annual_kwh)
    assert_equal(hpxml.dishwashers[0].label_electric_rate, dw_label_electric_rate)
    assert_equal(hpxml.dishwashers[0].label_gas_rate, dw_label_gas_rate)
    assert_equal(hpxml.dishwashers[0].label_annual_gas_cost, dw_label_annual_gas_cost)
    assert_equal(hpxml.dishwashers[0].label_usage, dw_label_usage)
    assert_equal(hpxml.dishwashers[0].place_setting_capacity, dw_place_setting_capacity)
    assert_equal(hpxml.dishwashers[0].usage_multiplier, dw_usage_multiplier)
  end

  def _test_default_refrigerator(hpxml, expected_refrig_values)
    refrig_location, refrig_rated_annual_kwh, refrig_usage_multiplier = expected_refrig_values
    assert_equal(hpxml.refrigerators[0].location, refrig_location)
    assert_equal(hpxml.refrigerators[0].rated_annual_kwh, refrig_rated_annual_kwh)
    assert_equal(hpxml.refrigerators[0].usage_multiplier, refrig_usage_multiplier)
  end

  def _test_default_cooking_range(hpxml, expected_cr_values)
    cr_location, cr_is_induction, cr_usage_multiplier = expected_cr_values
    assert_equal(hpxml.cooking_ranges[0].location, cr_location)
    assert_equal(hpxml.cooking_ranges[0].is_induction, cr_is_induction)
    assert_equal(hpxml.cooking_ranges[0].usage_multiplier, cr_usage_multiplier)
  end

  def _test_default_oven(hpxml, expected_oven_values)
    assert_equal(hpxml.ovens[0].is_convection, expected_oven_values)
  end

  def _test_default_std_hot_water_distribution(hpxml, expected_std_hw_piping_length)
    assert_in_epsilon(hpxml.hot_water_distributions[0].standard_piping_length, expected_std_hw_piping_length, 0.01)
  end

  def _test_default_recirc_hot_water_distribution(hpxml, expected_recirc_hw_dist_values)
    recirc_piping_length, recirc_branch_piping_length, recirc_pump_power = expected_recirc_hw_dist_values
    assert_in_epsilon(hpxml.hot_water_distributions[0].recirculation_piping_length, recirc_piping_length, 0.01)
    assert_in_epsilon(hpxml.hot_water_distributions[0].recirculation_branch_piping_length, recirc_branch_piping_length, 0.01)
    assert_in_epsilon(hpxml.hot_water_distributions[0].recirculation_pump_power, recirc_pump_power, 0.01)
  end

  def _test_default_solar_thermal_system(hpxml, expected_storage_volume)
    assert_in_epsilon(hpxml.solar_thermal_systems[0].storage_volume, expected_storage_volume)
  end

  def default_hpxml(hpxml_name)
    hpxml = HPXML.new(hpxml_path: File.join(@root_path, 'workflow', 'sample_files', hpxml_name))

    hpxml.hvac_distributions.each do |hvac_distribution|
      hvac_distribution.ducts.each do |duct|
        duct.duct_location = nil
        duct.duct_surface_area = nil
      end
    end

    hpxml.pv_systems.each do |pv|
      pv.inverter_efficiency = nil
      pv.system_losses_fraction = nil
    end

    hpxml.building_construction.conditioned_building_volume = nil
    hpxml.building_construction.average_ceiling_height = 10

    hpxml.clothes_washers[0].location = nil
    hpxml.clothes_washers[0].integrated_modified_energy_factor = nil
    hpxml.clothes_washers[0].rated_annual_kwh = nil
    hpxml.clothes_washers[0].label_electric_rate = nil
    hpxml.clothes_washers[0].label_gas_rate = nil
    hpxml.clothes_washers[0].label_annual_gas_cost = nil
    hpxml.clothes_washers[0].capacity = nil
    hpxml.clothes_washers[0].label_usage = nil
    hpxml.clothes_washers[0].usage_multiplier = nil

    hpxml.clothes_dryers[0].location = nil
    hpxml.clothes_dryers[0].control_type = nil
    hpxml.clothes_dryers[0].combined_energy_factor = nil
    hpxml.clothes_dryers[0].usage_multiplier = nil

    hpxml.dishwashers[0].location = nil
    hpxml.dishwashers[0].rated_annual_kwh = nil
    hpxml.dishwashers[0].label_electric_rate = nil
    hpxml.dishwashers[0].label_gas_rate = nil
    hpxml.dishwashers[0].label_annual_gas_cost = nil
    hpxml.dishwashers[0].label_usage = nil
    hpxml.dishwashers[0].place_setting_capacity = nil
    hpxml.dishwashers[0].usage_multiplier = nil
    
    hpxml.refrigerators[0].location = nil
    hpxml.refrigerators[0].rated_annual_kwh = nil
    hpxml.refrigerators[0].usage_multiplier = nil
    
    hpxml.cooking_ranges[0].location = nil
    hpxml.cooking_ranges[0].is_induction = nil
    hpxml.cooking_ranges[0].usage_multiplier = nil

    hpxml.ovens[0].is_convection = nil

    if hpxml.hot_water_distributions[0].system_type == HPXML::DHWDistTypeStandard
      hpxml.hot_water_distributions[0].standard_piping_length = nil
    end

    if hpxml.hot_water_distributions[0].system_type == HPXML::DHWDistTypeRecirc
      hpxml.hot_water_distributions[0].recirculation_piping_length = nil
      hpxml.hot_water_distributions[0].recirculation_branch_piping_length = nil
      hpxml.hot_water_distributions[0].recirculation_pump_power = nil
    end

    if not hpxml.solar_thermal_systems[0].collector_area.nil?
      hpxml.solar_thermal_systems[0].storage_volume = nil
    end

    # save new file
    hpxml_name = File.basename(@tmp_hpxml_path)
    XMLHelper.write_file(hpxml.to_oga, @tmp_hpxml_path)

    return hpxml
  end
end
