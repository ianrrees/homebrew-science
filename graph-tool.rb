class GraphTool < Formula
  desc "efficient network analysis"
  homepage "http://graph-tool.skewed.de/"
  revision 4

  stable do
    url "https://downloads.skewed.de/graph-tool/graph-tool-2.18.tar.bz2"
    sha256 "3c4929fb7b6bae13a12115afdf8c07d6531aeeba548305376ba7b0ac710ec4d4"

    # Fix compilation problem with newer CGAL
    # Remove at next release
    patch do
      url "https://aur.archlinux.org/cgit/aur.git/plain/0001-Fix-compilation-problem-with-newer-CGAL.patch?h=python-graph-tool"
      sha256 "6d325261f5e592c45c8eafb5c0b82d28e16fe4a11335d2c0c49f8e3439007f09"
    end
  end

  bottle do
    sha256 "cdaad683371103e808de36ad44655c63049139fdb1e5678d921a1caf70abb750" => :sierra
    sha256 "e0b5b40d4ab45d1bfe337acaa0eadbeaa019fa1804f9476c5623bbd4f4bd24f6" => :el_capitan
    sha256 "0e20e28fd211d4d281d3b8b4000ee67ddd0dcccc8841ced084b53d8d95ea321d" => :yosemite
  end

  head do
    url "https://git.skewed.de/count0/graph-tool.git"
    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  option "without-cairo", "Build without cairo support for plotting"
  option "without-gtk+3", "Build without gtk+3 support for interactive plotting"
  option "without-matplotlib", "Use a matplotlib you've installed yourself instead of a Homebrew-packaged matplotlib"
  option "without-numpy", "Use a numpy you've installed yourself instead of a Homebrew-packaged numpy"
  option "without-python", "Build without python2 support"
  option "without-scipy", "Use a scipy you've installed yourself instead of a Homebrew-packaged scipy"
  option "with-openmp", "Enable OpenMP multithreading"

  cxx11 = MacOS.version < :mavericks ? ["c++11"] : []

  depends_on :python3 => :optional
  with_pythons = build.with?("python3") ? ["with-python3"] : []

  depends_on "pkg-config" => :build
  depends_on "boost" => cxx11
  depends_on "boost-python" => cxx11 + with_pythons
  depends_on "cairomm" if build.with? "cairo"
  depends_on "cgal" => cxx11
  depends_on "google-sparsehash" => cxx11 + [:recommended]
  depends_on "gtk+3" => :recommended

  depends_on "homebrew/python/numpy" => [:recommended] + with_pythons
  depends_on "homebrew/python/scipy" => [:recommended] + with_pythons
  depends_on "homebrew/python/matplotlib" => [:recommended] + with_pythons

  if build.with? "cairo"
    depends_on "py2cairo" if build.with? "python"
    depends_on "py3cairo" if build.with? "python3"
  end

  if build.with? "gtk+3"
    depends_on "gnome-icon-theme"
    depends_on "librsvg" => "with-gtk+3"
    depends_on "pygobject3" => with_pythons
  end

  # We need a compiler with C++14 support.
  fails_with :llvm

  fails_with :clang do
    cause "Older versions of clang have buggy c++14 support."
    build 699
  end

  fails_with :gcc => "4.8" do
    cause "We need GCC 5.0 or above for sufficient c++14 support"
  end
  fails_with :gcc => "4.9" do
    cause "We need GCC 5.0 or above for sufficient c++14 support"
  end

  if MacOS.version == :mavericks
    fails_with :gcc => "6" do
      cause "GCC 6 fails with 'Internal compiler error' on Mavericks. You should install GCC 5 instead with 'brew tap homebrew/versions; brew install gcc5"
    end
  end

  # Fix build with boost 1.62.0 "no matching function for call to 'degree( ..."
  # graph-tool isn't using the stock filtered_graph.hpp, so its modified
  # header needs the same change that was made in boost 1.62.0 adding an
  # implementation of the 'degree' function for filtered_graph
  # Upstream issue 21 Oct 2016 https://git.skewed.de/count0/graph-tool/issues/347
  # Regression due to boostorg/graph@50bfd8d (boostorg/graph#29)
  patch do
    url "https://raw.githubusercontent.com/Homebrew/formula-patches/2310f75/graph-tool/add-degree-to-filtered-graph.diff"
    sha256 "72e9b37a5ed78f363da81e7f894579d2866dcb3ab4fab3eb92be582d4127b423"
  end

  needs :openmp if build.with? "openmp"

  def install
    if MacOS.version == :mavericks && (Tab.for_name("boost").stdlib == "libcxx" || Tab.for_name("boost-python").stdlib == "libcxx")
      odie "boost and boost-python must be built against libstdc++ on Mavericks. One way to achieve this, is to use GCC to compile both libraries."
    end

    system "./autogen.sh" if build.head?

    config_args = %W[
      --disable-debug
      --disable-dependency-tracking
      --prefix=#{prefix}
    ]

    # fix issue with boost + gcc with C++11/C++14
    ENV.append "CXXFLAGS", "-fext-numeric-literals" unless ENV.compiler == :clang
    config_args << "--disable-cairo" if build.without? "cairo"
    config_args << "--disable-sparsehash" if build.without? "google-sparsehash"
    config_args << "--enable-openmp" if build.with? "openmp"

    Language::Python.each_python(build) do |python, version|
      config_args_x = ["PYTHON=#{python}"]
      if OS.mac?
        config_args_x << "PYTHON_LDFLAGS=-undefined dynamic_lookup"
        config_args_x << "PYTHON_EXTRA_LDFLAGS=-undefined dynamic_lookup"
      end
      config_args_x << "--with-python-module-path=#{lib}/python#{version}/site-packages"

      if python == "python3"
        inreplace "configure", "libboost_python", "libboost_python3"
        inreplace "configure", "ax_python_lib=boost_python", "ax_python_lib=boost_python3"
      end

      mkdir "build-#{python}-#{version}" do
        system "../configure", *(config_args + config_args_x)
        system "make", "install"
      end
    end
  end

  test do
    Pathname("test.py").write <<-EOS.undent
      import graph_tool.all as gt
      g = gt.Graph()
      v1 = g.add_vertex()
      v2 = g.add_vertex()
      e = g.add_edge(v1, v2)
    EOS
    Language::Python.each_python(build) { |python, _| system python, "test.py" }
  end
end
