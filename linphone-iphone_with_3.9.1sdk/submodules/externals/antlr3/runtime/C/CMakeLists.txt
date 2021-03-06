############################################################################
# CMakeLists.txt
# Copyright (C) 2014  Belledonne Communications, Grenoble France
#
############################################################################
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
############################################################################

set(PACKAGE "libantlr3c")
set(PACKAGE_NAME "${PACKAGE}")
set(PACKAGE_VERSION "3.4-beta3")
set(PACKAGE_STRING "${PACKAGE_NAME} ${PACKAGE_VERSION}")
set(PACKAGE_BUGREPORT "jimi@temporal-wave.com")
set(PACKAGE_TARNAME "${PACKAGE_NAME}")
set(PACKAGE_URL "")
set(VERSION "${PACKAGE_VERSION}")


option(ENABLE_STATIC "Build static library (default is shared library)." OFF)
option(ENABLE_64BIT "Turns on flags that produce 64 bit object code if any are required." OFF)
option(ENABLE_DEBUGGER "Turns on default flags that include the antlr debugger in the runtime. Disable to remove debugger and the socket dependancies." ON)

if(ENABLE_64BIT)
	set(ANTLR3_USE_64BIT 1)
endif(ENABLE_64BIT)
if(NOT ENABLE_DEBUGGER)
	set(ANTLR3_NODEBUGGER 1)
endif(NOT ENABLE_DEBUGGER)


include(CheckIncludeFile)

check_include_file("arpa/nameser.h" HAVE_ARPA_NAMESER_H)
check_include_file("ctype.h" HAVE_CTYPE_H)
check_include_file("inttypes.h" HAVE_INTTYPES_H)
check_include_file("malloc.h" HAVE_MALLOC_H)
check_include_file("memory.h" HAVE_MEMORY_H)
check_include_file("netdb.h" HAVE_NETDB_H)
check_include_file("netinet/in.h" HAVE_NETINET_IN_H)
check_include_file("netinet/tcp.h" HAVE_NETINET_TCP_H)
check_include_file("socket.h" HAVE_SOCKET_H)
check_include_file("stdarg.h" HAVE_STDARG_H)
check_include_file("stdint.h" HAVE_STDINT_H)
check_include_file("stdlib.h" HAVE_STDLIB_H)
check_include_file("strings.h" HAVE_STRINGS_H)
check_include_file("string.h" HAVE_STRING_H)
check_include_file("sys/malloc.h" HAVE_SYS_MALLOC_H)
check_include_file("sys/socket.h" HAVE_SYS_SOCKET_H)
check_include_file("sys/stat.h" HAVE_SYS_STAT_H)
check_include_file("sys/types.h" HAVE_SYS_TYPES_H)
check_include_file("unistd.h" HAVE_UNISTD_H)

foreach(KEYWORD "inline" "__inline__" "__inline")
	if(NOT DEFINED C_INLINE)
		try_compile(C_HAS_${KEYWORD} "${CMAKE_CURRENT_BINARY_DIR}"
			"${CMAKE_CURRENT_SOURCE_DIR}/test_inline.c"
			COMPILE_DEFINITIONS "-Dinline=${KEYWORD}")
		if(C_HAS_${KEYWORD})
			set(C_INLINE TRUE)
			if(NOT "${KEYWORD}" STREQUAL "inline")
				set(inline ${KEYWORD})
			endif(NOT "${KEYWORD}" STREQUAL "inline")
		endif(C_HAS_${KEYWORD})
	endif(NOT DEFINED C_INLINE)
endforeach(KEYWORD)


configure_file(${CMAKE_CURRENT_SOURCE_DIR}/antlr3config.h.cmake ${CMAKE_CURRENT_BINARY_DIR}/antlr3config.h)


if(MSVC)
	add_definitions("/W3")
else(MSVC)
	add_definitions("-Wall")
endif(MSVC)


include_directories(
	include
	${CMAKE_CURRENT_BINARY_DIR}
)

add_subdirectory(include)
add_subdirectory(src)


install(FILES ${CMAKE_CURRENT_BINARY_DIR}/antlr3config.h
	DESTINATION include
	PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ
)

