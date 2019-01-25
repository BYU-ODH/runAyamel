import argparse

class ParseServices():
    files = {
        "d": "database.yml",
        "s": "server.yml",
        "v": "yvideo.yml",
        "x": "ylex.yml"
    }
    
    def __init__(self, prefix=""):
        self.empty()
        self.prefix=prefix

    def empty(self):
        self.args = {
            "build": [],
            "deploy": [],
            "services": []
        }

    def get_service(self, arg):
        if arg in self.files:
            return "%s " % self.files[arg]
    
    def parse(self, args=""):
        self.empty()
        if len(args) > 0:
            for arg in args:
                filename = self.get_service(arg)
                if filename is not None:
                    self.args["build"].append("-f")
                    self.args["build"].append(self.prefix+filename)
                    self.args["deploy"].append("-c")
                    self.args["deploy"].append(self.prefix+filename)
                    self.args["services"].append(filename.split(".")[0])
    
    def to_string(self):
        return "%s\n%s\n%s\n" % (" ".join(self.args["build"]), " ".join(self.args["deploy"]), " ".join(self.args["services"]))

def parse_options():
    parser = argparse.ArgumentParser(prog="Compose Files", description="Creates string of compose files from simpler syntax", add_help=True)
    parser.add_argument("-s", "--services", action="store", 
        help="which compose files to use. A string with some or all of the following letters: dsvx (database, server, yvideo, ylex")
    parser.add_argument("-p", "--prefix", action="store", help="Sets the path prefix to the files")
    return parser.parse_args()

if __name__ == "__main__":
    args = parse_options()
    if args.services is not None:
        parser = ParseServices(args.prefix if args.prefix is not None else "")
        parser.parse(args.services)
        print(parser.to_string())
