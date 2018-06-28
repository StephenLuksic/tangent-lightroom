// This is an open source non-commercial project. Dear PVS-Studio, please check it.
// PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com
/*
  ==============================================================================

    Misc.cpp

This file is part of MIDI2LR. Copyright 2015 by Rory Jaffe.

MIDI2LR is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

MIDI2LR is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
MIDI2LR.  If not, see <http://www.gnu.org/licenses/>.
  ==============================================================================
*/
#include "Misc.h"
#include "../JuceLibraryCode/JuceHeader.h"
#ifdef _WIN32
#include <gsl/gsl_util>
#include <ShlObj.h>
#include <unicode/unistr.h>
#include <Windows.h>
#endif

namespace rsj {
// from http://www.cplusplus.com/forum/beginner/175177 and
// https://github.com/gcc-mirror/gcc/blob/master/libstdc%2B%2B-v3/libsupc%2B%2B/cxxabi.h#L156

#ifdef __GNUG__ // gnu C++ compiler
#include <cxxabi.h>
#include <memory>
#include <type_traits>
   template<typename T>[[nodiscard]] T Demangle(const char* mangled_name) noexcept
   {
      static_assert(::std::is_pointer<T>() == false,
          "Result must be copied as __cxa_demagle returns "
          "pointer to temporary. Cannot use pointer type "
          "for this template.");
      ::std::size_t len = 0;
      int status = 0;
      ::std::unique_ptr<char, decltype(&::std::free)> ptr(
          abi::__cxa_demangle(mangled_name, nullptr, &len, &status), &::std::free);
      if (status)
         return mangled_name;
      return ptr.get();
   }
#else  // ndef _GNUG_
   template<typename T>[[nodiscard]] T Demangle(const char* mangled_name) noexcept
   {
      return mangled_name;
   }
#endif // _GNUG_
   void Log(const juce::String& info)
   {
      if (juce::Logger::getCurrentLogger())
         juce::Logger::writeToLog(juce::Time::getCurrentTime().toISO8601(false) + ": " + info);
   }

   void LogAndAlertError(const juce::String& error_text)
   {
      juce::NativeMessageBox::showMessageBox(juce::AlertWindow::WarningIcon, "Error", error_text);
      Log(error_text);
   }
   // use typeid(this).name() for first argument to add class information
   // typical call: rsj::ExceptionResponse(typeid(this).name(), __func__, e);
   void ExceptionResponse(const char* id, const char* fu, const ::std::exception& e) noexcept
   {
      try {
         const auto error_text{juce::String("Exception ") + e.what() + ' '
                               + Demangle<juce::String>(id) + "::" + fu + " Version "
                               + ProjectInfo::versionString};
         LogAndAlertError(error_text);
      }
      catch (...) { //-V565
      }
   }

#ifdef _WIN32
   template<typename T, typename R> auto UTFConvert(::std::basic_string<T>&& input)
   {
      if constexpr (::std::is_same<T, R>::value)
         return ::std::forward<R>(input);
      else if constexpr (sizeof(R) == sizeof(T))
         return ::std::forward<R>(reinterpret_cast<R>(input));
      else
         return static_cast<R>(input); // will fail
   }

   template<typename T, typename R>
   ::std::basic_string<R> UTFConvert(const ::std::basic_string_view<T>& input)
   {
      constexpr auto sizeR{sizeof(R)};
      constexpr auto sizeT{sizeof(T)};
      if constexpr (::std::is_same<T, R>::value)
         return input;
      else if constexpr (sizeT == sizeR)
         return reinterpret_cast<R>(input);
      else if constexpr (sizeR == 2 && sizeT == 1) {
         const auto uc{::icu::UnicodeString::fromUTF8(reinterpret_cast<::std::string>(input))};
         return ::std::basic_string<R>(reinterpret_cast<R*>(uc.getBuffer()));
      }
      else if constexpr (sizeR == 2 && sizeT == 4) {
         const auto uc{::icu::UnicodeString::fromUTF32(
             reinterpret_cast<UChar32*>(input.c_str()), input.length())};
         return ::std::basic_string<R>(reinterpret_cast<R*>(uc.getBuffer()));
      }
      else
         return static_cast<R>(input); // haven't finished everything yet--this will error
   }

   ::std::wstring AppDataFilePath(const ::std::wstring& file_name)
   {
      wchar_t* pathptr{nullptr};
      auto dp = gsl::finally([&pathptr] {
         if (pathptr)
            CoTaskMemFree(pathptr);
      });
      const HRESULT hr = SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0, nullptr, &pathptr);
      if (SUCCEEDED(hr))
         return ::std::wstring(pathptr) + L"\\MIDI2LR\\" + file_name;
      return ::std::wstring(file_name);
   }
   ::std::wstring AppDataFilePath(const ::std::string& file_name)
   {
      return AppDataFilePath(UTFConvert<char, wchar_t>(file_name));
   }
#endif
} // namespace rsj