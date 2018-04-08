# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6
PYTHON_COMPAT=( python{2_7,3_4,3_5,3_6} )

inherit cmake-utils eutils flag-o-matic python-any-r1 xdg-utils
if [[ ${PV} = *9999* ]]; then
	inherit git-r3
	EGIT_REPO_URI="https://github.com/doxygen/doxygen.git"
	SRC_URI=""
else
	SRC_URI="https://ftp.stack.nl/pub/users/dimitri/${P}.src.tar.gz"
	KEYWORDS="alpha amd64 arm ~arm64 hppa ia64 ~mips ppc ppc64 ~s390 ~sh sparc x86 ~amd64-fbsd ~x86-fbsd ~amd64-linux ~x86-linux ~ppc-macos ~x64-macos ~x86-macos ~x86-solaris"
fi
SRC_URI+=" https://dev.gentoo.org/~xarthisius/distfiles/doxywizard.png"

DESCRIPTION="Documentation system for most programming languages"
HOMEPAGE="https://www.stack.nl/~dimitri/doxygen/"

LICENSE="GPL-2"
SLOT="0"
IUSE="clang debug doc dot doxysearch latex qt5 sqlite userland_GNU"

RDEPEND="app-text/ghostscript-gpl
	dev-lang/perl
	media-libs/libpng:0=
	virtual/libiconv
	clang? ( sys-devel/clang:= )
	dot? (
		media-gfx/graphviz
		media-libs/freetype
	)
	doxysearch? ( =dev-libs/xapian-1.2* )
	latex? ( app-text/texlive[extra] )
	qt5? (
		dev-qt/qtgui:5
		dev-qt/qtwidgets:5
	)
	sqlite? ( dev-db/sqlite:3 )
	"

REQUIRED_USE="doc? ( latex )"

DEPEND="sys-devel/flex
	sys-devel/bison
	doc? ( ${PYTHON_DEPS} )
	${RDEPEND}"

# src_test() defaults to make -C testing but there is no such directory (bug #504448)
RESTRICT="test"

PATCHES=(
	"${FILESDIR}/${PN}-1.8.9.1-empty-line-sigsegv.patch" #454348
	"${FILESDIR}/${PN}-1.8.12-link_with_pthread.patch"
	"${FILESDIR}/${PN}-1.8.13-NULL-dereference.patch"
)

DOCS=( LANGUAGE.HOWTO README.md )

pkg_setup() {
	use doc && python-any-r1_pkg_setup
}

src_prepare() {
	cmake-utils_src_prepare

	# Ensure we link to -liconv
	if use elibc_FreeBSD && has_version dev-libs/libiconv || use elibc_uclibc; then
		local pro
		for pro in */*.pro.in */*/*.pro.in; do
			echo "unix:LIBS += -liconv" >> "${pro}" || die
		done
	fi

	# Call dot with -Teps instead of -Tps for EPS generation - bug #282150
	sed -i -e '/addJob("ps"/ s/"ps"/"eps"/g' src/dot.cpp || die

	# fix pdf doc
	sed -i.orig -e "s:g_kowal:g kowal:" \
		doc/maintainers.txt || die

	if is-flagq "-O3" ; then
		ewarn
		ewarn "Compiling with -O3 is known to produce incorrectly"
		ewarn "optimized code which breaks doxygen."
		ewarn
		elog
		elog "Continuing with -O2 instead ..."
		elog
		replace-flags "-O3" "-O2"
	fi
}

src_configure() {
	local mycmakeargs=(
		-DDOC_INSTALL_DIR="share/doc/${P}"
		-Duse_libclang=$(usex clang)
		-Dbuild_doc=$(usex doc)
		-Dbuild_search=$(usex doxysearch)
		-Dbuild_wizard=$(usex qt5)
		-Duse_sqlite3=$(usex sqlite)
		)

	cmake-utils_src_configure
}

src_compile() {
	cmake-utils_src_compile

	if use doc; then
		export VARTEXFONTS="${T}/fonts" # bug #564944

		if ! use dot; then
			sed -i -e "s/HAVE_DOT               = YES/HAVE_DOT    = NO/" \
				{Doxyfile,doc/Doxyfile} \
				|| die "disabling dot failed"
		fi
		cmake-utils_src_make -C "${BUILD_DIR}" docs
	fi
}

src_install() {
	cmake-utils_src_install

	if use qt5; then
		doicon "${DISTDIR}/doxywizard.png"
		make_desktop_entry doxywizard "DoxyWizard ${PV}" \
			"/usr/share/pixmaps/doxywizard.png" \
			"Development"
	fi
}

pkg_postinst() {
	xdg_desktop_database_update

	elog
	elog "For examples and other goodies, see the source tarball. For some"
	elog "example output, run doxygen on the doxygen source using the"
	elog "Doxyfile provided in the top-level source dir."
	elog
	elog "Disabling the dot USE flag will remove the GraphViz dependency,"
	elog "along with Doxygen's ability to generate diagrams in the docs."
	elog "See the Doxygen homepage for additional helper tools to parse"
	elog "more languages."
	elog
}

pkg_postrm() {
	xdg_desktop_database_update
}
