import os
import sys
import getpass
import cx_Oracle
import subprocess
import re
from configparser import ConfigParser
from datetime import datetime
import logging

# global Variables

# baseName = None
# user = None
# filepath = None
# pgmpath = None
# logpath = None
# arcpath = None
# rejpath = None
# logfile = None


def init():
    try:
        # set initialization variables
        date_stamp = datetime.now().strftime('%y%m%d.%H%M%S')
        global scriptName
        global baseName
        global user
        global filepath
        global pgmpath
        global logpath
        global arcpath
        global rejpath
        global logfile
        global loadctl
        global connectionString

        scriptName = sys.argv[0]
        baseName = os.path.basename(scriptName)
        scriptName = os.path.splitext(baseName)[0]
        user = getpass.getuser()
        # program exit codes
        pgmcc = 0
        errcode = 0

        # set program paths and archive paths.
        filepath = os.getenv('IN')

        pgmpath = os.path.join(os.getenv('MMHOME', 'scripts'))
        # logpath = os.getenv('LOGDIR')

        logpath = os.getcwd()
        print(logpath)

        arcpath = os.getenv('ARCHIVE_IN')  # archive path

        rejpath = os.getenv('REJECT')  # rejected file directory

        # logfile

        logfile = os.path.join(logpath, '.'.join([scriptName, date_stamp, 'log']))
        print(logfile)

        # sql loader params

        loadctl = os.path.join(pgmpath, 'ascena_mass_tsf_stg.ctl')
        # loadlog = os.path.join(pgmpath, )

        # os.chdir(os.getenv('MMHOME'))
        # set logging info

        logging.basicConfig(
            filename=logfile,
            filemode='w',
            level=logging.DEBUG,
            format="%(asctime)s: %(filename)s: %(levelname)s: %(funcName)s: line: %(lineno)d: %(message)s"
        )

        # read configuration file
        config = ConfigParser()
        config.read('app.Config')
        options = config.options('appSettings')
        for option in options:
            connectionString = config.get('appSettings', option)

        params = {}
        params['scriptName'] = scriptName
        params['user'] = user
        params['logpath'] = logpath
        params['arcpath'] = arcpath
        print(params)

        envsetting = """
        ****************************************************************************
            script name = {scriptName}
            user        = {user}
            logpath     = {logpath}
            arcpath     = {arcpath}
        *****************************************************************************
            """.format(**params)
        logging.info(envsetting)
    except:
        logging.critical('Encountered error while setting the initial variables.', exc_info=True)
        return 1
    else:
        logging.info('Successfully set the program initialization variables.')
        return 0


def check_files(file):
    file_cnt = 0

    logging.info('Start Processing File: %s.' % file)
    if os.path.getsize(file) > 0:
        logging.info('Data file %s found: proceeding.' % file)
        file_cnt += 1
        return True
    else:
        logging.info('Error: No data available in the file %s.' % file)
        logging.info('Moving the file %s to rejected file dir %s.' % (file, rejpath))
        # os.rename(file, os.path.join(rejpath, file))
        return False


def execute_sql(conn, command):
    try:
        cur = conn.cursor()
        # cur.prepare(sql)
        cur.execute(command)
    except:
        logging.critical('Sql Statement Failed', exc_info=True)
        return 1
    else:
        logging.info('Sql Statement Successfully executed.')
        return 0


def logon():
    try:
        db_conn = cx_Oracle.connect(connectionString)
    except:
        logging.critical('Unable to make a database connection', exc_info=True)
        return 1
    else:
        logging.info('Database connection successfully established.')
        return db_conn


def load_stage():
    subprocess.call(['ls', '-la'], stdout=subprocess.PIPE)


if __name__ == '__main__':

    init()
    # logon()
    # get the lsit of valid files to process
    fileFormat = re.compile(r'ascena_(.)*_mass_tsf_req(.)*.csv')
    fileList = [file for file in os.listdir() if fileFormat.search(file)]
    if not fileList:
        logging.warning('No File Found To Process.Program will now exit.')
        exit(0)
    else:
        logging.info('%d files found. Processing ...' % len(fileList))
        logging.info('Validating Individual Files.')
        # Loop through files
        for file in fileList:
            if check_files(file):
                # load_stage()
                pass

    # load_stage()

