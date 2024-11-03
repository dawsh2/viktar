#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <time.h>
#include <pwd.h>
#include <grp.h>
#include <stdint.h>
#include <openssl/md5.h>
#include <openssl/evp.h> 

#include "viktar.h"

// Global variables
int verbose = FALSE;
viktar_action_t action = ACTION_NONE;
char *archive_file = NULL;

// Function prototypes
void print_help(void);
void process_args(int argc, char *argv[]);
int validate_archive(int fd);
void create_archive(char *archive_name, char **files, int file_count);
void extract_files(char *archive_name, char **files, int file_count);
void print_toc(char *archive_name, int long_format);
void validate_content(char *archive_name);
void calculate_md5(void *data, size_t size, uint8_t *digest);
void print_permissions(mode_t mode);
void truncate_filename(const char *input, char *output);
char *format_time(struct timespec ts);


int main(int argc, char *argv[]) {
    process_args(argc, argv);
    
    switch (action) {
        case ACTION_CREATE:
            create_archive(archive_file, argv + optind, argc - optind);
            break;
            
        case ACTION_EXTRACT:
            extract_files(archive_file, argv + optind, argc - optind);
            break;
            
        case ACTION_TOC_SHORT:
            print_toc(archive_file, FALSE);
            break;
            
        case ACTION_TOC_LONG:
            print_toc(archive_file, TRUE);
            break;
            
        case ACTION_VALIDATE:
            validate_content(archive_file);
            break;
            
        case ACTION_NONE:
            fprintf(stderr, "No action specified\n");
            print_help();
            exit(1);
    }
    
    return 0;
}

void process_args(int argc, char *argv[]) {
    int opt;
    
    while ((opt = getopt(argc, argv, OPTIONS)) != -1) {
        switch (opt) {
            case 'v':
                verbose = TRUE;
                if (verbose) {
                    fprintf(stderr, "Verbose mode enabled\n");
                }
                break;
                
            case 'h':
                print_help();
                exit(0);
                
            case 'f':
                archive_file = optarg;
                break;
                
            case 'x':
                action = ACTION_EXTRACT;
                break;
                
            case 'c':
                action = ACTION_CREATE;
                break;
                
            case 't':
                action = ACTION_TOC_SHORT;
                break;
                
            case 'T':
                action = ACTION_TOC_LONG;
                break;
                
            case 'V':
                action = ACTION_VALIDATE;
                break;
                
            default:
                fprintf(stderr, "Unknown option: %c\n", opt);
                print_help();
                exit(1);
        }
    }
}

void print_help(void) {
  printf("help text\n");
  printf("    ./viktar\n");
  printf("    Options: xctTf:Vhv\n");
  printf("        -x        extract file/files from archive\n");
  printf("        -c        create an archive file\n");
  printf("        -t        display a short table of contents of the archive file\n");
  printf("        -T        display a long table of contents of the archive file\n");
  printf("        Only one of xctTV can be specified\n");
  printf("        -f filename    use filename as the archive file\n");
  printf("        -v        give verbose diagnostic messages\n");
  printf("        -h        display this AMAZING help message\n");
  exit(EXIT_SUCCESS);
}

int validate_archive(int fd) {
    char buffer[strlen(VIKTAR_TAG) + 1];  /* +1 for null terminator */
    ssize_t bytes_read;

    /* Save current position */
    off_t current_pos = lseek(fd, 0, SEEK_CUR);
    
    /* Go to start of file */
    lseek(fd, 0, SEEK_SET);
    
    /* Read exactly the length of VIKTAR_TAG */
    bytes_read = read(fd, buffer, strlen(VIKTAR_TAG));
    
    /* null terminate the buffer */
    buffer[strlen(VIKTAR_TAG)] = '\0';
    
    /* If read failed or not enough bytes read */
    if (bytes_read != strlen(VIKTAR_TAG)) {
        if (verbose) {
            fprintf(stderr, "reading archive from stdin\n");
            fprintf(stderr, "not a viktar file: \"stdin\"\n");
        }
        return FALSE;
    }
    
    /* Compare the tag */
    if (strncmp(buffer, VIKTAR_TAG, strlen(VIKTAR_TAG)) != 0) {
        if (verbose) {
            if (isatty(fd)) {
                fprintf(stderr, "not a viktar file: \"stdin\"\n");
            } else {
                fprintf(stderr, "not a viktar file: \"%s\"\n", "stdin");
            }
        }
        return FALSE;
    }

    /* Restore original position */
    lseek(fd, current_pos + strlen(VIKTAR_TAG), SEEK_SET);
    
    return TRUE;
}

void calculate_md5(void *data, size_t size, uint8_t *digest) {
    EVP_MD_CTX *mdctx;
    unsigned int digest_len;

    mdctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(mdctx, EVP_md5(), NULL);
    EVP_DigestUpdate(mdctx, data, size);
    EVP_DigestFinal_ex(mdctx, digest, &digest_len);
    EVP_MD_CTX_free(mdctx);
}


/* Helper function to truncate filenames to VIKTAR_MAX_FILE_NAME_LEN-1 characters */
void truncate_filename(const char *input, char *output) {
    size_t max_len = VIKTAR_MAX_FILE_NAME_LEN - 1;  /* 21 characters */
    
    /* Clear the entire buffer first */
    memset(output, 0, VIKTAR_MAX_FILE_NAME_LEN);
    
    /* If input is longer than max_len, truncate it */
    if (strlen(input) > max_len) {
        memcpy(output, input, max_len);
        output[max_len] = '\0';  /* Ensure null termination */
        if (verbose) {
            fprintf(stderr, "Truncated filename '%s' to '%s' (max length %zu)\n", 
                    input, output, max_len);
        }
    } else {
        strcpy(output, input);
    }
}

void create_archive(char *archive_name, char **files, int file_count) {
    int fd;
    mode_t mode = 0644;
    int i;
    struct stat st;
    viktar_header_t header;
    viktar_footer_t footer;
    int input_fd;
    char *buffer;
    ssize_t bytes_read;
    char truncated_name[VIKTAR_MAX_FILE_NAME_LEN];
    
    if (archive_name == NULL) {
        fd = STDOUT_FILENO;
    } else {
        fd = open(archive_name, O_WRONLY | O_CREAT | O_TRUNC, mode);
        if (fd < 0) {
            perror("Error creating archive");
            exit(1);
        }
    }
    
    write(fd, VIKTAR_TAG, strlen(VIKTAR_TAG));
    
    for (i = 0; i < file_count; i++) {
        if (stat(files[i], &st) < 0) {
            perror("Error getting file stats");
            continue;
        }
        
        /* Zero out the header completely */
        memset(&header, 0, sizeof(header));
        
        /* Truncate the filename if necessary */
        truncate_filename(files[i], truncated_name);
        
        /* Copy the truncated name into the header */
        memcpy(header.viktar_name, truncated_name, VIKTAR_MAX_FILE_NAME_LEN);
        
        /* Store the rest of the file information */
        header.st_size = st.st_size;
        header.st_mode = st.st_mode;
        header.st_uid = st.st_uid;
        header.st_gid = st.st_gid;
        header.st_atim = st.st_atim;
        header.st_mtim = st.st_mtim;
        
        /* Calculate MD5 and write header */
        calculate_md5(&header, sizeof(header), footer.md5sum_header);
        write(fd, &header, sizeof(header));
        
        /* Open and read the actual file */
        input_fd = open(files[i], O_RDONLY);
        if (input_fd < 0) {
            perror("Error opening input file");
            continue;
        }
        
        buffer = malloc(st.st_size);
        if (buffer == NULL) {
            perror("Memory allocation failed");
            close(input_fd);
            continue;
        }
        
        bytes_read = read(input_fd, buffer, st.st_size);
        if (bytes_read == st.st_size) {
            calculate_md5(buffer, st.st_size, footer.md5sum_data);
            write(fd, buffer, st.st_size);
            write(fd, &footer, sizeof(footer));
        }
        
        free(buffer);
        close(input_fd);
    }
    
    if (fd != STDOUT_FILENO) {
        close(fd);
    }
}




/* void create_archive(char *archive_name, char **files, int file_count) { */
/*     int fd; */
/*     mode_t mode = 0644; */
/*     int i; */
/*     struct stat st; */
/*     viktar_header_t header; */
/*     viktar_footer_t footer; */
/*     int input_fd; */
/*     char *buffer; */
/*     ssize_t bytes_read; */
    
/*     if (archive_name == NULL) { */
/*         fd = STDOUT_FILENO; */
/*     } else { */
/*         fd = open(archive_name, O_WRONLY | O_CREAT | O_TRUNC, mode); */
/*         if (fd < 0) { */
/*             perror("Error creating archive"); */
/*             exit(1); */
/*         } */
/*     } */
    
/*     write(fd, VIKTAR_TAG, strlen(VIKTAR_TAG)); */
    
/*     for (i = 0; i < file_count; i++) { */
/*         if (stat(files[i], &st) < 0) { */
/*             perror("Error getting file stats"); */
/*             continue; */
/*         } */
        
/*         memset(&header, 0, sizeof(header)); */
/*         strncpy(header.viktar_name, files[i], VIKTAR_MAX_FILE_NAME_LEN - 1); */
/*         header.st_size = st.st_size; */
/*         header.st_mode = st.st_mode; */
/*         header.st_uid = st.st_uid; */
/*         header.st_gid = st.st_gid; */
/*         header.st_atim = st.st_atim; */
/*         header.st_mtim = st.st_mtim; */
        
/*         calculate_md5(&header, sizeof(header), footer.md5sum_header); */
/*         write(fd, &header, sizeof(header)); */
        
/*         input_fd = open(files[i], O_RDONLY); */
/*         if (input_fd < 0) { */
/*             perror("Error opening input file"); */
/*             continue; */
/*         } */
        
/*         buffer = malloc(st.st_size); */
/*         if (buffer == NULL) { */
/*             perror("Memory allocation failed"); */
/*             close(input_fd); */
/*             continue; */
/*         } */
        
/*         bytes_read = read(input_fd, buffer, st.st_size); */
/*         if (bytes_read == st.st_size) { */
/*             calculate_md5(buffer, st.st_size, footer.md5sum_data); */
/*             write(fd, buffer, st.st_size); */
/*             write(fd, &footer, sizeof(footer)); */
/*         } */
        
/*         free(buffer); */
/*         close(input_fd); */
/*     } */
    
/*     if (fd != STDOUT_FILENO) { */
/*         close(fd); */
/*     } */
/* } */


void print_permissions(mode_t mode) {
    printf("%c%c%c%c%c%c%c%c%c",
           (mode & S_IRUSR) ? 'r' : '-',
           (mode & S_IWUSR) ? 'w' : '-',
           (mode & S_IXUSR) ? 'x' : '-',
           (mode & S_IRGRP) ? 'r' : '-',
           (mode & S_IWGRP) ? 'w' : '-',
           (mode & S_IXGRP) ? 'x' : '-',
           (mode & S_IROTH) ? 'r' : '-',
           (mode & S_IWOTH) ? 'w' : '-',
           (mode & S_IXOTH) ? 'x' : '-');
}

char *format_time(struct timespec ts) {
    static char buffer[64];
    struct tm *tm_info;
    
    tm_info = localtime(&ts.tv_sec);
    strftime(buffer, sizeof(buffer), "%Y-%m-%d %H:%M:%S %Z", tm_info);
    return buffer;
}
void extract_files(char *archive_name, char **files, int file_count) {
    int fd;
    viktar_header_t header;
    viktar_footer_t footer;
    uint8_t calc_md5_header[MD5_DIGEST_LENGTH];
    uint8_t calc_md5_data[MD5_DIGEST_LENGTH];
    char *buffer;
    int extract;
    int out_fd;
    struct timespec times[2];
    int i;
    
    if (archive_name == NULL) {
        fd = STDIN_FILENO;
        if (verbose) {
            fprintf(stderr, "reading archive from stdin\n");
        }
    } else {
        fd = open(archive_name, O_RDONLY);
        if (fd < 0) {
            perror("Error opening archive");
            exit(1);
        }
        if (verbose) {
            fprintf(stderr, "reading archive file: \"%s\"\n", archive_name);
        }
    }
    
    if (!validate_archive(fd)) {
        fprintf(stderr, "not a viktar file: \"%s\"\n", 
                archive_name ? archive_name : "stdin");
        exit(1);
    }
    
    while (read(fd, &header, sizeof(header)) == sizeof(header)) {
        extract = file_count == 0;  /* Extract all if no files specified */
        
        /* Check if this file should be extracted */
        for (i = 0; i < file_count && !extract; i++) {
            if (strncmp(header.viktar_name, files[i], VIKTAR_MAX_FILE_NAME_LEN) == 0) {
                extract = 1;
            }
        }
        
        /* Allocate buffer for file content */
        buffer = malloc(header.st_size);
        if (buffer == NULL) {
            perror("Memory allocation failed");
            exit(1);
        }
        
        /* Read file content */
        if (read(fd, buffer, header.st_size) != header.st_size) {
            perror("Error reading archive content");
            free(buffer);
            continue;
        }
        
        /* Read footer */
        if (read(fd, &footer, sizeof(footer)) != sizeof(footer)) {
            perror("Error reading archive footer");
            free(buffer);
            continue;
        }

        if (extract) {
            /* Calculate MD5 for both header and data */
            calculate_md5(&header, sizeof(header), calc_md5_header);
            calculate_md5(buffer, header.st_size, calc_md5_data);

            /* Check header MD5 */
            if (memcmp(calc_md5_header, footer.md5sum_header, MD5_DIGEST_LENGTH) != 0) {
                fprintf(stderr, "Warning: Header MD5 mismatch for %s\n", header.viktar_name);
            }

            /* Check data MD5 */
            if (memcmp(calc_md5_data, footer.md5sum_data, MD5_DIGEST_LENGTH) != 0) {
                fprintf(stderr, "Warning: MD5 mismatch for %s\n", header.viktar_name);
            }
            
            /* Create output file with correct permissions */
            out_fd = open(header.viktar_name, O_WRONLY | O_CREAT | O_TRUNC, 
                         header.st_mode & 07777);
            if (out_fd < 0) {
                perror("Error creating output file");
                free(buffer);
                continue;
            }
            
            /* Write file content */
            if (write(out_fd, buffer, header.st_size) != header.st_size) {
                perror("Error writing output file");
                close(out_fd);
                free(buffer);
                continue;
            }
            
            /* Set timestamps */
            times[0] = header.st_atim;
            times[1] = header.st_mtim;
            if (futimens(out_fd, times) < 0) {
                perror("Error setting file times");
            }
            
            close(out_fd);
            
            if (verbose) {
                fprintf(stderr, "Extracted: %s\n", header.viktar_name);
            }
        } else {
            /* Skip to next file if not extracting */
            if (verbose) {
                fprintf(stderr, "Skipping: %s\n", header.viktar_name);
            }
        }
        
        free(buffer);
    }
    
    if (fd != STDIN_FILENO) {
        close(fd);
    }
}


void print_toc(char *archive_name, int long_format) {
    int fd;
    viktar_header_t header;
    viktar_footer_t footer;
    struct passwd *pw;
    struct group *gr;
    char mode_str[11];
    //    uint8_t calc_md5[MD5_DIGEST_LENGTH];
    int i;
    
    if (archive_name == NULL) {
        fd = STDIN_FILENO;
    } else {
        fd = open(archive_name, O_RDONLY);
        if (fd < 0) {
            perror("Error opening archive");
            exit(1);
        }
    }
    
    if (!validate_archive(fd)) {
        fprintf(stderr, "Invalid archive format\n");
        exit(1);
    }

    printf("Contents of viktar file: %s\n", archive_name ? archive_name : "stdin");
    
    while (read(fd, &header, sizeof(header)) == sizeof(header)) {
        printf("\tfile name: %s\n", header.viktar_name);
        
        if (long_format) {
            /* Create mode string */
            mode_str[0] = S_ISDIR(header.st_mode) ? 'd' : '-';
            mode_str[1] = (header.st_mode & S_IRUSR) ? 'r' : '-';
            mode_str[2] = (header.st_mode & S_IWUSR) ? 'w' : '-';
            mode_str[3] = (header.st_mode & S_IXUSR) ? 'x' : '-';
            mode_str[4] = (header.st_mode & S_IRGRP) ? 'r' : '-';
            mode_str[5] = (header.st_mode & S_IWGRP) ? 'w' : '-';
            mode_str[6] = (header.st_mode & S_IXGRP) ? 'x' : '-';
            mode_str[7] = (header.st_mode & S_IROTH) ? 'r' : '-';
            mode_str[8] = (header.st_mode & S_IWOTH) ? 'w' : '-';
            mode_str[9] = (header.st_mode & S_IXOTH) ? 'x' : '-';
            mode_str[10] = '\0';

            pw = getpwuid(header.st_uid);
            gr = getgrgid(header.st_gid);
            
            printf("\t\tmode:           %s\n", mode_str);
            printf("\t\tuser:           %s\n", pw ? pw->pw_name : "unknown");
            printf("\t\tgroup:          %s\n", gr ? gr->gr_name : "unknown");
            printf("\t\tsize:           %lld\n", (long long)header.st_size);
            printf("\t\tmtime:          %s\n", format_time(header.st_mtim));
            printf("\t\tatime:          %s\n", format_time(header.st_atim));

            /* Read footer to get MD5 sums */
            lseek(fd, header.st_size, SEEK_CUR);
            if (read(fd, &footer, sizeof(footer)) == sizeof(footer)) {
                printf("\t\tmd5 sum header: ");
                for (i = 0; i < MD5_DIGEST_LENGTH; i++) {
                    printf("%02x", footer.md5sum_header[i]);
                }
                printf("\n\t\tmd5 sum data:   ");
                for (i = 0; i < MD5_DIGEST_LENGTH; i++) {
                    printf("%02x", footer.md5sum_data[i]);
                }
                printf("\n");
            }
            continue; /* Skip the lseek at the end since we already moved the file pointer */
        }
        
        lseek(fd, header.st_size + sizeof(viktar_footer_t), SEEK_CUR);
    }
    
    if (fd != STDIN_FILENO) {
        close(fd);
    }
}



void validate_content(char *archive_name) {
    int fd;
    viktar_header_t header;
    viktar_footer_t footer;
    uint8_t calc_md5[MD5_DIGEST_LENGTH];
    int member_count = 0;
    
    if (archive_name == NULL) {
        fd = STDIN_FILENO;
    } else {
        fd = open(archive_name, O_RDONLY);
        if (fd < 0) {
            perror("Error opening archive");
            exit(1);
        }
    }
    
    if (!validate_archive(fd)) {
        fprintf(stderr, "Invalid archive format\n");
        exit(1);
    }
    
    while (read(fd, &header, sizeof(header)) == sizeof(header)) {
      char *buffer = malloc(header.st_size);
        int validation_failed = FALSE;
        member_count++;
        printf("Validation for data member %d:\n", member_count);
        
        // Validate header MD5
        calculate_md5(&header, sizeof(header), calc_md5);
        

        if (buffer == NULL) {
            perror("Memory allocation failed");
            exit(1);
        }
        
        // Read file content
        if (read(fd, buffer, header.st_size) != header.st_size) {
            perror("Error reading archive content");
            free(buffer);
            continue;
        }
        
        // Read footer
        if (read(fd, &footer, sizeof(footer)) != sizeof(footer)) {
            perror("Error reading archive footer");
            free(buffer);
            continue;
        }
        
        // Compare header MD5
        if (memcmp(calc_md5, footer.md5sum_header, MD5_DIGEST_LENGTH) != 0) {
            validation_failed = TRUE;
            printf("*** Header MD5 does not match:\n");
            printf("found: ");
            for (int i = 0; i < MD5_DIGEST_LENGTH; i++)
                printf("%02x", calc_md5[i]);
            printf("\nin file: ");
            for (int i = 0; i < MD5_DIGEST_LENGTH; i++)
                printf("%02x", footer.md5sum_header[i]);
            printf("\n");
        }
        
        // Calculate and compare data MD5
        calculate_md5(buffer, header.st_size, calc_md5);
        if (memcmp(calc_md5, footer.md5sum_data, MD5_DIGEST_LENGTH) != 0) {
            validation_failed = TRUE;
            printf("*** Data MD5 does not match:\n");
            printf("found: ");
            for (int i = 0; i < MD5_DIGEST_LENGTH; i++)
                printf("%02x", calc_md5[i]);
            printf("\nin file: ");
            for (int i = 0; i < MD5_DIGEST_LENGTH; i++)
                printf("%02x", footer.md5sum_data[i]);
            printf("\n");
        }
        
        if (validation_failed) {
            printf("*** Validation failure: %s for member %d\n",
                   archive_name ? archive_name : "stdin",
                   member_count);
        }
        
        free(buffer);
    }
    
    if (fd != STDIN_FILENO) {
        close(fd);
    }
}