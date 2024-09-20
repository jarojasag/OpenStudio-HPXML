import os
import xml.etree.ElementTree as ET

def modify_xml_element(root, xpath, new_value, namespace):
    """
    Modifies the XML element found at the specified xpath with a new value.

    Args:
    root (xml.etree.ElementTree.Element): The root element of the XML tree.
    xpath (str): The XPath string to locate the element.
    new_value (str): The new value to set for the found element.
    namespace (dict): The namespace dictionary used in the XML.

    Returns:
    bool: True if the modification was successful, False otherwise.
    """
    element = root.find(xpath, namespace)
    if element is not None:
        element.text = new_value
        print(f"Element {xpath} updated to {new_value}.")
        return True
    else:
        print(f"Element {xpath} not found.")
        return False

# Output Folders 

output_dir = r"C:\Users\jrojasa\OneDrive - RAND Corporation\Documents\Out of the Frying Pan\Modified XML"
if not os.path.exists(output_dir):
    os.makedirs(output_dir)
    print(f"Directory {output_dir} created.")

### Base_LA.xml
tree = ET.parse(r"C:\Users\jrojasa\OneDrive - RAND Corporation\Documents\Out of the Frying Pan\base.xml")
root = tree.getroot()
namespace = {'hpxml': 'http://hpxmlonline.com/2023/09'}

# Year
modify_xml_element(root, './/hpxml:Building/hpxml:BuildingDetails/hpxml:ClimateandRiskZones/hpxml:ClimateZoneIECC/hpxml:Year', '2021', namespace)
# ClimateZone
modify_xml_element(root, './/hpxml:Building/hpxml:BuildingDetails/hpxml:ClimateandRiskZones/hpxml:ClimateZoneIECC/hpxml:ClimateZone', '3B', namespace)
# WeatherStation
modify_xml_element(root, './/hpxml:Building/hpxml:BuildingDetails/hpxml:ClimateandRiskZones/hpxml:WeatherStation/hpxml:Name', 'USA_CA_LosAngeles_HW_Historical_MostIntense_MostSevere_2018', namespace)
# EPWFilePath
modify_xml_element(root, './/hpxml:Building/hpxml:BuildingDetails/hpxml:ClimateandRiskZones/hpxml:WeatherStation/hpxml:extension/hpxml:EPWFilePath', 'USA_CA_LosAngeles_HW_Historical_MostIntense_MostSevere_2018.epw', namespace)

output_file_path = os.path.join(output_dir, 'Base_LA.xml')
tree.write(output_file_path)
print(f"File saved as {output_file_path}.")


### Base_TripnWindow.xml
tree = ET.parse(r"C:\Users\jrojasa\OneDrive - RAND Corporation\Documents\Out of the Frying Pan\base.xml")
root = tree.getroot()
namespace = {'hpxml': 'http://hpxmlonline.com/2023/09'}

# UFactor and SHGC for each window
for window in root.findall(".//hpxml:Window", namespace):
    system_identifier = window.find("hpxml:SystemIdentifier", namespace)
    
    if system_identifier is not None:
        window_id = system_identifier.get('id')
        
        if window_id == 'Window1':
            modify_xml_element(window, 'hpxml:UFactor', '0.27', namespace)
            modify_xml_element(window, 'hpxml:SHGC', '0.31', namespace)
        elif window_id == 'Window2':
            modify_xml_element(window, 'hpxml:UFactor', '0.27', namespace)
            modify_xml_element(window, 'hpxml:SHGC', '0.31', namespace)
        elif window_id == 'Window3':
            modify_xml_element(window, 'hpxml:UFactor', '0.27', namespace)
            modify_xml_element(window, 'hpxml:SHGC', '0.31', namespace)
        elif window_id == 'Window4':
            modify_xml_element(window, 'hpxml:UFactor', '0.27', namespace)
            modify_xml_element(window, 'hpxml:SHGC', '0.31', namespace)

output_file_path = os.path.join(output_dir, 'Base_TripnWindow.xml')
tree.write(output_file_path)
print(f"File saved as {output_file_path}.")


### Base_noAC130F.xml
tree = ET.parse(r"C:\Users\jrojasa\OneDrive - RAND Corporation\Documents\Out of the Frying Pan\base.xml")
root = tree.getroot()
namespace = {'hpxml': 'http://hpxmlonline.com/2023/09'}

# SetpointTempCoolingSeason
modify_xml_element(root, './/hpxml:Building/hpxml:BuildingDetails/hpxml:Systems/hpxml:HVAC/hpxml:HVACControl/hpxml:SetpointTempCoolingSeason', '130', namespace)

output_file_path = os.path.join(output_dir, 'Base_noAC130F.xml')
tree.write(output_file_path)
print(f"File saved as {output_file_path}.")


### Base_set82.xml
tree = ET.parse(r"C:\Users\jrojasa\OneDrive - RAND Corporation\Documents\Out of the Frying Pan\base.xml")
root = tree.getroot()
namespace = {'hpxml': 'http://hpxmlonline.com/2023/09'}

# SetpointTempCoolingSeason
modify_xml_element(root, './/hpxml:Building/hpxml:BuildingDetails/hpxml:Systems/hpxml:HVAC/hpxml:HVACControl/hpxml:SetpointTempCoolingSeason', '82', namespace)

output_file_path = os.path.join(output_dir, 'Base_set82.xml')
tree.write(output_file_path)
print(f"File saved as {output_file_path}.")


### Base_roomAC.xml
tree = ET.parse(r"C:\Users\jrojasa\OneDrive - RAND Corporation\Documents\Out of the Frying Pan\base.xml")
root = tree.getroot()
namespace = {'hpxml': 'http://hpxmlonline.com/2023/09'}

# CoolingSystemType
modify_xml_element(root, './/hpxml:Building/hpxml:BuildingDetails/hpxml:Systems/hpxml:HVAC/hpxml:HVACPlant/hpxml:CoolingSystem/hpxml:CoolingSystemType', 'room air conditioner', namespace)
# CoolingCapacity
modify_xml_element(root, './/hpxml:Building/hpxml:BuildingDetails/hpxml:Systems/hpxml:HVAC/hpxml:HVACPlant/hpxml:CoolingSystem/hpxml:CoolingCapacity', '8000.0', namespace)
# FractionCoolLoadServed
modify_xml_element(root, './/hpxml:Building/hpxml:BuildingDetails/hpxml:Systems/hpxml:HVAC/hpxml:HVACPlant/hpxml:CoolingSystem/hpxml:FractionCoolLoadServed', '0.33', namespace)
# AnnualCoolingEfficiency value
modify_xml_element(root, './/hpxml:Building/hpxml:BuildingDetails/hpxml:Systems/hpxml:HVAC/hpxml:HVACPlant/hpxml:CoolingSystem/hpxml:AnnualCoolingEfficiency/hpxml:Value', '8.5', namespace)
# Delete CompressorType element
compressor_type_element = root.find('.//hpxml:Building/hpxml:BuildingDetails/hpxml:Systems/hpxml:HVAC/hpxml:HVACPlant/hpxml:CoolingSystem/hpxml:CompressorType', namespace)
if compressor_type_element is not None:
    compressor_type_element.clear()  # Removes all content of the element
    print("CompressorType element deleted.")

output_file_path = os.path.join(output_dir, 'Base_roomAC.xml')
tree.write(output_file_path)
print(f"File saved as {output_file_path}.")