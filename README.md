## Protobuf Crash Example

This project demonstrates what I believe is a problem with a vended protobuf library from a pod dependency being linked into the executable a second time when running a test target inside a hosted app, causing that library to abort during the `_dyld_start` step.

Run `pod install` before opening the workspace.

## libprotobuf

This project includes the [TensorIO](https://github.com/doc-ai/tensorio-ios) pod, which has [TensorIOTensorFlow](https://github.com/doc-ai/tensorio-tensorflow-ios) as a dependency. TensorIOTensorFlow itself vends the following libraries:

```rb
s.vendored_libraries = [
  'Libraries/libnsync.a',
  'Libraries/libprotobuf.a'
]
```

Note that `libprotobuf` is one of the libraries.

## Test target exception during _dyld_start

In a new project with default settings after running pod install I can run the application target in a simulator without any problems. However, when I go to run a unit test, the executable aborts with the following error:

```
[libprotobuf ERROR google/protobuf/descriptor_database.cc:118] 
File already exists in database: tensorflow/contrib/boosted_trees/proto/tree_config.proto

[libprotobuf FATAL google/protobuf/descriptor.cc:1367] CHECK failed: GeneratedDatabase()->Add(encoded_file_descriptor, size): 
```

The failing check calls abort() after a function in the libprotobuf library returns false when it tries to add a key-value pair to a c++ map that already exists in that map. We can see this taking place exactly where the error message is telling us to look: *descriptor_database.cc:118*.

What is particularly interesting, however, is when this crash occurs. This is the stack trace:

```
Thread 1 Queue : com.apple.main-thread (serial)
#0	0x00007fff51b6133a in __pthread_kill ()
#1	0x00007fff51c0be60 in pthread_kill ()
#2	0x00007fff51af0b7c in abort ()
#3	0x00000001092d62dd in google::protobuf::internal::LogMessage::Finish() ()
#4	0x00000001092fbddc in google::protobuf::DescriptorPool::InternalAddGeneratedFile(void const*, int) ()
#5	0x000000010934d098 in google::protobuf::internal::AddDescriptors(google::protobuf::internal::DescriptorTable const*) ()
#6	0x000000010934d07c in google::protobuf::internal::AddDescriptors(google::protobuf::internal::DescriptorTable const*) ()
#7	0x000000010e0a46d9 in ImageLoaderMachO::doModInitFunctions(ImageLoader::LinkContext const&) ()
#8	0x000000010e0a4ace in ImageLoaderMachO::doInitialization(ImageLoader::LinkContext const&) ()
#9	0x000000010e09f868 in ImageLoader::recursiveInitialization(ImageLoader::LinkContext const&, unsigned int, char const*, ImageLoader::InitializerTimingList&, ImageLoader::UninitedUpwards&) ()
#10	0x000000010e09dd2c in ImageLoader::processInitializers(ImageLoader::LinkContext const&, unsigned int, ImageLoader::InitializerTimingList&, ImageLoader::UninitedUpwards&) ()
#11	0x000000010e09ddcc in ImageLoader::runInitializers(ImageLoader::LinkContext const&, ImageLoader::InitializerTimingList&) ()
#12	0x000000010e092270 in dyld::initializeMainExecutable() ()
#13	0x000000010e0961bb in dyld::_main(macho_header const*, unsigned long, int, char const**, char const**, char const**, unsigned long*) ()
#14	0x000000010e0911cd in start_sim ()
#15	0x000000010e2f779a in dyld::useSimulatorDyld(int, macho_header const*, char const*, int, char const**, char const**, char const**, unsigned long*, unsigned long*) ()
#16	0x000000010e2f5432 in dyld::_main(macho_header const*, unsigned long, int, char const**, char const**, char const**, unsigned long*) ()
#17	0x000000010e2f0227 in dyldbootstrap::start(dyld3::MachOLoaded const*, int, char const**, dyld3::MachOLoaded const*, unsigned long*) ()
#18	0x000000010e2f0025 in _dyld_start ()

Thread 2#0	0x00007fff51b5c4ce in __workq_kernreturn ()
#1	0x00007fff51c08aa1 in _pthread_wqthread ()
#2	0x00007fff51c07b77 in start_wqthread ()
```

Note that the crash is occuring in `_dyld_start`

## The fix

There are two ways to fix this, both of which lead me to the same hypothesis. I have added the branches no-test-host-fix and linker-fix to demonstrate the fixes.

### 1. No test host

Set the Host Application for the test target to None.

Now, however, during the test targets linking step I get errors that symbols in the two vended libraries from TensorIOTensorFlow, *nsync* and *libprotobuf*, cannot be found. If I inspect the other linker flags, I see that those two libraries are linked into the host application but not into the test target. I can try to manually add them, but then I'm told that the libraries cannot be find.

The soultion is to comment out `inherit! :search_paths` for the tests target in the Podfile and to rebuild the project with `pod install`

Finally, check the tests target in Target Membership for any application module files I want to include in the test.

At this point I can run unit tests without any problems. You'll find these fixes in the *no-test-host-fix* branch of this repository.

### 2. Remove some other linker flags

From the test target's other linker flags build settings, remove $(inherited) and the references to the tensorflow.framework.

At this point I can run unit tests without any problems. You'll find these fixes in the *linker-fix* branch of this repository.

In fact, I can remove all the other linker flags from both the test target and the application target and everything works fine. So why does cocoapods set these at all?

## Hypothesis

The protobuf descriptor database is responsible for keeping track of the available protobuf descriptions, and these descipriton should only appear in the database once. When the libprotobuf library is loaded it initializes what I believe is a singleton descriptor database, searches for the available desciptors, and adds them to it.

My hypothesis is that the libprotobuf library is being linked twice into the executable when running tests in a host application and so is being loaded twice, leading to this second round of initalization with the singleton. It's not clear to me if it's linked the first time as a static library or a dynamic library, but it does seem clear that the library is being linked a second time as a dynamic library, and when the library is loaded a second time, key-values are being added a second time to the singleton map, which leads to the error.

If the protobuf library is being linked into the executable a second time with a test host is used, it's also not clear to me why the symbols from this library can't be found during the linker step when I clear the test host. It's like the library either isn't being linked at all, or it's being linked twice?

And why can I remove all of the linker flags from both the test target and the host application without any consequences? Why does cocoapods set these at all?