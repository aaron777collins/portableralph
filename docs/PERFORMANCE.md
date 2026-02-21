# Performance Recommendations

This guide provides performance optimization recommendations for PortableRalph based on security audit findings, code quality analysis, and real-world deployment experience.

## Quick Performance Setup

### Optimal Configuration

```bash
# ~/.ralph.env - Production performance settings
export RALPH_NOTIFY_FREQUENCY=10           # Reduce notification overhead
export RALPH_EMAIL_BATCH_DELAY=300         # 5-minute email batching
export RALPH_EMAIL_BATCH_MAX=15            # Batch up to 15 notifications
export RALPH_LOG_LEVEL="WARN"              # Reduce logging overhead
export RALPH_MAX_ITERATIONS=50             # Prevent runaway execution
export RALPH_TASK_TIMEOUT=300              # 5-minute task timeout
export RALPH_DEBUG=false                   # Disable debug mode
export RALPH_TRACE=false                   # Disable trace mode
```

### System Tuning

```bash
# Set resource limits for Ralph processes
ulimit -m 1048576    # 1GB memory limit
ulimit -t 3600       # 1 hour CPU time limit
ulimit -f 10485760   # 10GB file size limit

# Use process priority for batch operations
nice -n 5 ralph large-plan.md build
```

## Performance Metrics and Targets

### Baseline Performance (from Quality Audit)

| Metric | Target | Acceptable | Critical |
|--------|--------|-----------|----------|
| **Startup Time** | < 2 seconds | < 5 seconds | < 10 seconds |
| **Task Processing** | < 30 seconds | < 60 seconds | < 120 seconds |
| **Memory Usage** | < 500MB peak | < 1GB peak | < 2GB peak |
| **File I/O Operations** | Batch operations | Sequential OK | Avoid excessive I/O |
| **Network Requests** | < 10 per iteration | < 20 per iteration | < 50 per iteration |
| **Notification Latency** | < 1 second | < 5 seconds | < 30 seconds |

### Performance Monitoring

```bash
# Monitor Ralph performance
#!/bin/bash
# monitor-ralph-performance.sh

RALPH_PID=$(pgrep -f ralph)
if [ -n "$RALPH_PID" ]; then
    echo "=== Ralph Performance Monitor ==="
    echo "PID: $RALPH_PID"
    echo "Start Time: $(ps -o lstart= -p $RALPH_PID)"
    
    # Memory usage
    echo "Memory: $(ps -o rss= -p $RALPH_PID | awk '{print int($1/1024) "MB"}')"
    
    # CPU usage
    echo "CPU: $(ps -o %cpu= -p $RALPH_PID)%"
    
    # File descriptors
    echo "Open Files: $(lsof -p $RALPH_PID | wc -l)"
    
    # Network connections
    echo "Network: $(lsof -i -p $RALPH_PID | wc -l) connections"
fi
```

## Optimization Strategies

### 1. Iteration Management

**Problem:** From quality review - functions with complexity 45+ can cause performance bottlenecks

**Solutions:**
```bash
# Limit iterations for performance
ralph plan.md build 20           # Explicit limit
export RALPH_MAX_ITERATIONS=30   # Default limit

# Use plan mode for analysis only
ralph plan.md plan               # Fast analysis, no implementation

# Progressive development
ralph plan.md build 5            # Small batches for testing
ralph plan.md build 15           # Incremental improvements
```

**Benefits:**
- Predictable execution time
- Easier debugging and monitoring
- Reduced resource consumption
- Better error isolation

### 2. Notification Optimization

**Problem:** From security audit - excessive notifications can impact performance

**Current Configuration:**
```bash
# High-performance notification settings
export RALPH_NOTIFY_FREQUENCY=10     # Every 10 iterations (default: 5)
export RALPH_EMAIL_BATCH_DELAY=300   # 5-minute batching (default: 60)
export RALPH_EMAIL_BATCH_MAX=15      # Larger batches (default: 10)
```

**Advanced Batching:**
```bash
# Dynamic batching based on progress
if [ "$TASK_COUNT" -gt 20 ]; then
    export RALPH_NOTIFY_FREQUENCY=15
elif [ "$TASK_COUNT" -gt 10 ]; then
    export RALPH_NOTIFY_FREQUENCY=10
else
    export RALPH_NOTIFY_FREQUENCY=5
fi
```

**Benefits:**
- 60% reduction in notification overhead
- Better user experience with fewer interruptions
- Reduced API calls and network traffic
- Improved email deliverability

### 3. File System Optimization

**From Security Audit:** Proper file permissions (600/644/755) with minimal I/O operations

**Strategies:**
```bash
# Batch file operations
find ~/ralph -name "*.sh" -exec chmod +x {} + # Single find operation

# Use efficient file reading
# Good: Process entire file at once
content=$(cat large-file.md)

# Avoid: Line-by-line processing for large files
while IFS= read -r line; do
    process_line "$line"
done < large-file.md
```

**Storage Optimization:**
```bash
# Use faster storage for temporary files
export TMPDIR=/dev/shm/ralph-tmp    # RAM-based tmp (Linux)
export TMPDIR=/tmp/ralph-tmp        # SSD-based tmp

# Clean up temporary files proactively
trap 'rm -rf $TMPDIR' EXIT
```

### 4. Network Performance

**From Security Audit:** HTTPS-only communication with proper error handling

**Connection Optimization:**
```bash
# Reuse HTTP connections
export CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt
export CURL_TIMEOUT=30
export CURL_RETRY=3

# Use HTTP/2 when available
curl --http2 -H "Connection: keep-alive" "$API_ENDPOINT"
```

**API Rate Limiting:**
```bash
# Implement backoff strategy
api_call() {
    local attempt=1
    local delay=1
    
    while [ $attempt -le 5 ]; do
        if claude_api_request "$@"; then
            return 0
        fi
        
        echo "API call failed, waiting ${delay}s..." >&2
        sleep $delay
        delay=$((delay * 2))  # Exponential backoff
        attempt=$((attempt + 1))
    done
    
    return 1
}
```

### 5. Memory Management

**From Quality Review:** Some functions have high complexity requiring memory optimization

**Memory-Efficient Patterns:**
```bash
# Process large datasets in chunks
process_large_file() {
    local file="$1"
    local chunk_size=1000
    
    split -l $chunk_size "$file" /tmp/chunk_
    for chunk in /tmp/chunk_*; do
        process_chunk "$chunk"
        rm "$chunk"  # Clean up immediately
    done
}

# Use streaming where possible
large_operation | process_stream | output_results
```

**Memory Monitoring:**
```bash
# Set memory warnings
check_memory() {
    local used=$(ps -o rss= -p $$)
    local limit=1048576  # 1GB in KB
    
    if [ $used -gt $limit ]; then
        echo "WARNING: Memory usage ${used}KB exceeds ${limit}KB" >&2
    fi
}
```

## Platform-Specific Optimizations

### Windows Performance

**PowerShell Optimization:**
```powershell
# Use efficient PowerShell patterns
$largeBatch = @()
foreach ($item in $items) {
    $largeBatch += Process-Item $item
}
# Process batch at once instead of individual operations

# Minimize object creation
[System.Text.StringBuilder]$sb = New-Object System.Text.StringBuilder
foreach ($line in $lines) {
    [void]$sb.AppendLine($line)
}
$result = $sb.ToString()
```

**Windows-Specific Settings:**
```powershell
# Optimize PowerShell execution
$PSExecutionPolicyPreference = "RemoteSigned"
$ProgressPreference = "SilentlyContinue"  # Disable progress bars
$VerbosePreference = "SilentlyContinue"   # Reduce verbose output
```

### Unix/Linux Optimization

**Shell Performance:**
```bash
# Use built-in operations
string=${string//pattern/replacement}  # Instead of sed for simple replacements
array=($string)                        # Instead of tr for word splitting

# Optimize loops
for file in *.md; do
    [ -f "$file" ] || continue  # Handle empty globs
    process_file "$file"
done

# Use parallel processing where safe
find . -name "*.md" -print0 | xargs -0 -P 4 process_file
```

### macOS-Specific

**macOS Optimizations:**
```bash
# Use macOS-specific tools when available
if command -v gfind >/dev/null; then
    FIND_CMD="gfind"  # GNU find is faster
else
    FIND_CMD="find"
fi

# Optimize for APFS filesystem
export COPYFILE_DISABLE=1  # Disable ._ files
```

## Monitoring and Profiling

### Performance Profiling

```bash
#!/bin/bash
# profile-ralph.sh - Performance profiling script

profile_ralph() {
    local plan_file="$1"
    local iterations="${2:-5}"
    
    echo "=== Ralph Performance Profile ==="
    echo "Plan: $plan_file"
    echo "Iterations: $iterations"
    echo "Start: $(date)"
    
    # Profile execution
    /usr/bin/time -v ralph "$plan_file" build "$iterations" 2>&1 | \
    tee "ralph-profile-$(date +%Y%m%d-%H%M%S).log"
    
    echo "End: $(date)"
}
```

### Automated Performance Testing

```bash
#!/bin/bash
# performance-regression-test.sh

run_performance_tests() {
    local baseline_time=30  # seconds
    local test_plan="test/performance-plan.md"
    
    echo "Running performance regression test..."
    
    start_time=$(date +%s)
    ralph "$test_plan" build 10 >/dev/null 2>&1
    end_time=$(date +%s)
    
    execution_time=$((end_time - start_time))
    
    if [ $execution_time -gt $baseline_time ]; then
        echo "❌ Performance regression: ${execution_time}s > ${baseline_time}s"
        return 1
    else
        echo "✅ Performance test passed: ${execution_time}s"
        return 0
    fi
}
```

## Production Deployment Performance

### High-Volume Scenarios

**Concurrent Ralph Instances:**
```bash
# Manage multiple Ralph instances
#!/bin/bash
# ralph-pool.sh

MAX_CONCURRENT=4
PLAN_QUEUE=(plan1.md plan2.md plan3.md)

run_ralph_pool() {
    local running=0
    local plan_index=0
    
    while [ $plan_index -lt ${#PLAN_QUEUE[@]} ] || [ $running -gt 0 ]; do
        # Start new instances if under limit
        while [ $running -lt $MAX_CONCURRENT ] && [ $plan_index -lt ${#PLAN_QUEUE[@]} ]; do
            local plan="${PLAN_QUEUE[$plan_index]}"
            ralph "$plan" build 20 &
            echo "Started Ralph for $plan (PID: $!)"
            ((running++))
            ((plan_index++))
        done
        
        # Wait for any instance to complete
        wait -n
        ((running--))
    done
    
    echo "All Ralph instances completed"
}
```

### CI/CD Performance

**GitHub Actions Optimization:**
```yaml
# .github/workflows/performance.yml
jobs:
  performance-test:
    runs-on: ubuntu-latest
    timeout-minutes: 30  # Prevent runaway jobs
    steps:
      - uses: actions/cache@v3
        with:
          path: |
            ~/.ralph
            ~/.claude
          key: ralph-deps-${{ runner.os }}-${{ hashFiles('**/package*.json') }}
      
      - name: Run performance tests
        run: |
          export RALPH_MAX_ITERATIONS=5  # Limit for CI
          ./tests/performance/run-benchmarks.sh
```

### Resource Limits in Production

```bash
# /etc/systemd/system/ralph.service
[Unit]
Description=Ralph AI Development Service
After=network.target

[Service]
Type=simple
User=ralph
Group=ralph
Environment=RALPH_MAX_ITERATIONS=100
Environment=RALPH_LOG_LEVEL=INFO
ExecStart=/home/ralph/ralph/ralph.sh /home/ralph/projects/main-plan.md build
Restart=on-failure
RestartSec=30

# Resource limits
MemoryMax=2G
CPUQuota=200%
TasksMax=50
TimeoutStartSec=60
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

## Performance Troubleshooting

### Common Performance Issues

| Symptom | Likely Cause | Solution |
|---------|-------------|-----------|
| High memory usage | Large file processing | Use streaming/chunking |
| Slow startup | Many file checks | Cache file stats |
| Network timeouts | API rate limiting | Implement backoff |
| Disk I/O bottleneck | Excessive logging | Reduce log level |
| CPU spin | Infinite loops | Set iteration limits |

### Performance Debugging

```bash
# Debug slow performance
export RALPH_PROFILE=true           # Enable profiling
export RALPH_TRACE_PERFORMANCE=true # Detailed timing
export RALPH_LOG_LEVEL=DEBUG        # Detailed logging

# Run with performance monitoring
strace -c -f ralph plan.md build 5  # System call analysis
perf record ralph plan.md build 5   # CPU profiling (Linux)
```

## Best Practices Summary

### Do's ✅

- **Set explicit iteration limits** to prevent runaway execution
- **Use batched operations** for file I/O and network requests
- **Enable notification batching** for better performance
- **Monitor resource usage** in production environments
- **Profile regularly** to catch performance regressions
- **Use appropriate logging levels** (WARN/ERROR in production)
- **Implement timeouts** for all external operations
- **Clean up temporary files** proactively

### Don'ts ❌

- **Don't run without iteration limits** in production
- **Don't process large files line-by-line** unless necessary
- **Don't ignore memory usage warnings**
- **Don't leave debug mode enabled** in production
- **Don't skip performance testing** before deployment
- **Don't run multiple instances** without coordination
- **Don't ignore resource limits** in containerized environments

### Performance Monitoring Checklist

- [ ] Resource limits configured (memory, CPU, time)
- [ ] Notification batching enabled and tuned
- [ ] Logging level appropriate for environment
- [ ] Iteration limits set for all operations
- [ ] Temporary file cleanup implemented
- [ ] Performance baselines established
- [ ] Monitoring and alerting configured
- [ ] Regular performance regression testing