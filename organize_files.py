import os

home_dir = 'C:\\Users\\alaskar\\Documents\\Project Ascena\\'


def move_files():
    pass


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
        # for root, dirs, files in os.walk(".", topdown=False):
        #     for file in files:
        #         # os.remove(os.path.join(root, file))
        #         print(os.path.join(root, file))
        #     for name in dirs:
        #         print(os.path.join(root, name))
        pass


def compress_files():
    pass


if __name__ == '__main__':
    create_folders()
    move_files()
