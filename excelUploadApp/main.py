from csvFileCreator import CsvFileCreator
import logging
from datetime import datetime


# basis settings for logging
logfile = "excel_parser_{0}".format(datetime.now().strftime('%Y%m%d%H%M%S'))
logging.basicConfig(
    filename="excel_parser.log",
    level=logging.DEBUG,
    filemode="w",
    format="%(asctime)s: (%(filename)s): %(levelname)s: "
           "%(funcName)s Line: %(lineno)d - %(message)s",
    datefmt="%m/%d/%Y %I:%M:%S %p"
)

# main function


def main():
    excel_obj = CsvFileCreator('testfile.xlsx')
    config_dict = excel_obj.configsectionmap('Coreappsetting')
    if config_dict:
        logging.info('Application settings:')
        logging.info('Delimiter: %s, '
                     'EnableExcel: %s'
                     'EnableCSV: %s'
                     % (config_dict['delimeter'],
                        config_dict['enableexcel'],
                        config_dict['enablecsv']))
    parsed_data = excel_obj.parse_excel()
    if not excel_obj.write_csv('Extracted.csv', parsed_data, '|'):
        print('Failed To Write csv')
    else:
        print('CSV File Generated')


if __name__ == '__main__':
    main()