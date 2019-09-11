import os
import sys
import getpass
import cx_Oracle
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
            format="%(asctime)s: %(filename)s: %(levelname)s: %(funcName)s: line: %(lineno)d: -%(message)s"
        )

        # read configuration file
        config = ConfigParser()
        config.read('app.Config')
        options = config.options('appSettings')
        for option in options:
            connectionString = config.get('appSettings', option)

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
        return 0
    else:
        logging.info('Error: No data available in the file %s.' % file)
        logging.info('Moving the file %s to rejected file dir %s.' % (file, rejpath))
        os.rename(file, os.path.join(rejpath, file))
        return 3


def execute_sql(conn, command):
    try:
        cur = conn.cursor()
        # cur.prepare(sql)
        cur.execute(command)
    except Exception:
        logging.critical('Sql Statement Failed', exc_info=True)
        return 1
    else:
        logging.info('Sql Statement Successfully executed.')
        return 0


def logon():
    try:
        db_conn=cx_Oracle.connect(connectionString)
    except:
        logging.critical('Unable to make a database connection', exc_info=True)
        return 1
    else:
        logging.info('Database connection successfully established.')
        return db_conn


if __name__ == '__main__':
    init()
    logon()
