import os
import cx_Oracle
import shutil

# home_dir = 'C:\\Users\\alaskar\\Documents\Project Ascena\'
home_dir = os.path.join('C:\\', 'Users', 'alaskar', 'Documents', 'Project Ascena')
print(home_dir)
defined_dirs = ('family', 'seashell', 'sequels')


def move_files():
    # Get all files inside code repositoty
    # files = next(os.walk(os.path.join(home_dir, 'code repository')))[2]
    # print(files)
    # for root, dirs, files in os.walk("code repository"):
    #     print(root)
    #     for dir in dirs:
    #         print(dir)
    path = os.path.join(home_dir, 'code repository', 'LBCA')
    for file in os.listdir(path):
        # print(os.path.join(home_dir, 'code repository', 'LBCA'))
        # print(os.path.abspath(file))
        isFile = os.path.isfile(os.path.join(path, file))
        if isFile:
            ext = os.path.splitext(file)[1][1:]
            if ext == 'sql':
                dest = os.path.join(home_dir, 'photos', 'sequels')
                shutil.copy(os.path.join(path, file), os.path.join(dest, file))
            elif ext == 'pc':
                dest = os.path.join(home_dir, 'photos', 'family')
                shutil.copy(os.path.join(path, file), os.path.join(dest, file))
            elif ext == 'sh' or ext == 'ksh':
                dest = os.path.join(home_dir, 'photos', 'seashell')
                shutil.copy(os.path.join(path, file), os.path.join(dest, file))
    path = os.path.join(home_dir, 'code repository', 'MAU')
    for file in os.listdir(path):
        # print(os.path.join(home_dir, 'code repository', 'LBCA'))
        # print(os.path.abspath(file))
        isFile = os.path.isfile(os.path.join(path, file))
        if isFile:
            ext = os.path.splitext(file)[1][1:]
            if ext == 'sql':
                dest = os.path.join(home_dir, 'photos', 'sequels')
                shutil.copy(os.path.join(path, file), os.path.join(dest, file))
            elif ext == 'pc':
                dest = os.path.join(home_dir, 'photos', 'family')
                shutil.copy(os.path.join(path, file), os.path.join(dest, file))
            elif ext == 'sh' or ext == 'ksh':
                dest = os.path.join(home_dir, 'photos', 'seashell')
                shutil.copy(os.path.join(path, file), os.path.join(dest, file))
    path = os.path.join(home_dir, 'code repository', 'DRS')
    for file in os.listdir(path):
        # print(os.path.join(home_dir, 'code repository', 'LBCA'))
        # print(os.path.abspath(file))
        isFile = os.path.isfile(os.path.join(path, file))
        if isFile:
            ext = os.path.splitext(file)[1][1:]
            if ext == 'sql':
                dest = os.path.join(home_dir, 'photos', 'sequels')
                shutil.copy(os.path.join(path, file), os.path.join(dest, file))
            elif ext == 'pc':
                dest = os.path.join(home_dir, 'photos', 'family')
                shutil.copy(os.path.join(path, file), os.path.join(dest, file))
            elif ext == 'sh' or ext == 'ksh':
                dest = os.path.join(home_dir, 'photos', 'seashell')
                shutil.copy(os.path.join(path, file), os.path.join(dest, file))


def create_folders():
    # change to homedir
    if os.getcwd() != home_dir:
        os.chdir(home_dir)
    # check if the folder exists
    if not os.path.exists('photos'):
        os.mkdir('photos')
        # os.mkdir('\photos\family')
        os.mkdir(os.path.join('photos', 'family'))
        os.mkdir(os.path.join('photos', 'seashell'))
        os.mkdir(os.path.join('photos', 'sequels'))
        # print(os.path.join('photos', 'seashell'))
        # os.mkdir('\\photos\\seashell')
        # os.mkdir('\\photos\\sequels')
    else:
        # empty the contents
        root = next(os.walk('photos'))[0]
        dirs = next(os.walk('photos'))[1]
        files = next(os.walk('photos'))[2]
        print(root)
        print(dirs)
        print(files)

        # for root, dirs, files in os.walk('photos', topdown=False):
        # for file in files:
        #     # os.remove(os.path.join(root, file))
        #
        # print(root)
        # If a directory does not exist, create it else empty it
        # if os.path.exists()
        # for dir_name in dirs:
        #     # os.rmdir(os.path.join(root, dir_name)
        #     abs_path = os.path.join(root, dir_name)
        for d in defined_dirs:
            try:
                indx = dirs.index(d)
                abs_path = os.path.join(root, d)
                print(abs_path)
                # If found, then empty it
                if indx >= 0:
                    for file in os.listdir(abs_path):
                        # Empty the folders
                        os.remove(os.path.join(abs_path, file))
            except ValueError:
                os.mkdir(os.path.join(root, d))


def compress_files():
    pass

# def db_connect():
#     return cx_Oracle.connect(dsn='RMSCECA1')


if __name__ == '__main__':
    create_folders()
    move_files()
    # db_connect()


